import fp,
       boost.types,
       asyncdispatch,
       os

type
  ActorCommand = enum amQuit
  ActorBaseObj {.inheritable.} = object
    name: string
    cmdChannel: Channel[ActorCommand]
    thread: Thread[ForeignCell]
  ActorBase* = ref ActorBaseObj
  ActorBasePtr* = ptr ActorBaseObj
  ActorHandlerS*[T,S] = proc(self: ActorPtr[T,S], msg: T, state: S): Option[S] {.gcsafe.}
  ActorHandler*[T] = proc(self: ActorPtr[T,Unit], msg: T): bool {.gcsafe.}
  ActorMessage[T] = object
    msg: T
    timeout: int
  Actor*[T,S] = ref ActorObj[T,S]
  ActorPtr*[T,S] = ptr ActorObj[T,S]
  ActorThreadArgs[T,S] = ref object
    actor: ActorPtr[T,S]
    handler: ActorHandlerS[T,S]
    initialstate: S
  ActorObj[T,S] = object of ActorBaseObj
    ## The actor type. Actors are always typed
    channel: Channel[ActorMessage[T]]
    handler: ActorHandlerS[T,S]

proc mkAmMsg[T](msg: T, timeout = 0): ActorMessage[T] = ActorMessage[T](msg: msg, timeout: timeout)

template ActorPtrT*(T: untyped): untyped =
  var x: T
  type(x[].addr)

proc initActorBase(actor: ActorBase, name: string) =
  actor.cmdChannel.open
  actor.name = ""

proc initActor*[T,S](actor: var Actor[T,S], handler: ActorHandlerS[T,S]): ActorPtr[T,S] {.discardable, raises: [].} =
  new actor
  initActorBase(actor, "")
  open(actor.channel)
  actor.handler = handler
  actor[].addr

proc initActor*[T](actor: var Actor[T,Unit], handler: ActorHandler[T]): ActorPtr[T,Unit] {.discardable, raises: [].} =
  initActor(
    actor,
    proc(self: ActorPtr[T, Unit], msg: T, state: Unit): Option[Unit] =
      if handler(self, msg):
        ().some
      else:
        Unit.none
  )

proc initActor*[T,S](handler: ActorHandlerS[T,S]): Actor[T,S] {.raises: [].} =
  discard initActor(result, handler)

proc initActor*[T](handler: ActorHandler[T]): Actor[T,Unit] {.raises: [].} =
  discard initActor(result, handler)

proc setName*[T,S](a: Actor[T,S], name: string): Actor[T,S] {.discardable, raises: [].} =
  a.name = name
  result = a

proc handleCmd(cmd: ActorCommand): bool =
  result = true
  if cmd == amQuit:
    result = false

proc actorThread[T,S](fc: ForeignCell) {.thread, nimcall.} =
  var args: ActorThreadArgs[T,S]
  # TODO: https://github.com/nim-lang/Nim/issues/5166
  let srcArgs = cast[ActorThreadArgs[T,S]](fc.data)
  deepCopy(args, srcArgs)
  fc.dispose
  let cmdChannel = args.actor.cmdChannel.addr
  let channel = args.actor.channel.addr
  var state = args.initialState
  try:
    var cont = true
    while cont:
      try:
        #TODO: https://github.com/nim-lang/Nim/issues/5155
        sleep(1)
        poll(0)
      except:
        discard
      block:
        ## First we need to check command channel
        var mmsg = cmdChannel[].tryRecv()
        if mmsg.dataAvailable and not handleCmd(mmsg.msg):
          cont = false
      if cont:
        ## Then we need to check messages channel
        var mmsg = channel[].tryRecv()
        if mmsg.dataAvailable:
          let am = mmsg.msg
          if am.timeout <= 0:
            let so = args.handler(args.actor, am.msg, state)
            if so.isDefined:
              state = so.get
            else:
              cont = false
          else:
            var f: Future[void] = sleepAsync(am.timeout)
            #TODO: WTF? Is it the new ll bug? It's not working without msg copy
            let msg = am.msg
            proc cb() {.closure,gcsafe.} =
              channel[].send(mkAmMsg(msg))
            `callback=`(f, cb)
  finally:
    try:
      channel[].close
    except:
      discard
  except:
    discard

proc start*[T,S](a: Actor[T,S], initialState: S): EitherS[Unit] =
  tryS do() -> auto:
    let args = ActorThreadArgs[T,S](actor: addr a[], handler: a.handler, initialState: initialState)
    a.thread.createThread(actorThread[T,S], system.protect(cast[pointer](args)))
    ()

proc start*[T](a: Actor[T,Unit]): EitherS[Unit] =
  a.start(())

proc sendCmdImpl(a: ActorBase|ActorBasePtr, cmd: ActorCommand): EitherS[Unit] {.discardable.} =
  tryS do -> auto:
    a.cmdChannel.send(cmd)
    ()

proc sendImpl[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: ActorMessage[T]): EitherS[Unit] {.discardable.} =
  tryS do -> auto:
    a.channel.send(msg)
    ()

proc stop*(a: ActorBase): EitherS[Unit] =
  a.sendCmdImpl(amQuit)

proc join*(a: ActorBase): EitherS[Unit] =
  tryS do() -> auto:
    a.thread.joinThread
    ()

proc send*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T): EitherS[Unit] {.discardable.} =
  a.sendImpl(mkAmMsg(msg))

proc `!`*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T): EitherS[Unit] {.discardable.} =
  a.send(msg)

proc sendDeferred*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T, timeout: int): EitherS[Unit] {.discardable.} =
  a.sendImpl(mkAmMsg(msg, timeout))

