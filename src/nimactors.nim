import fp,
       boost.types,
       asyncdispatch,
       os

type
  ActorHandlerS*[T,S] = proc(self: ActorPtr[T,S], msg: T, state: S): Option[S] {.gcsafe.}
  ActorHandler*[T] = proc(self: ActorPtr[T,Unit], msg: T): bool {.gcsafe.}
  ActorMessageType = enum amQuit, amMsg
  ActorMessage[T] = object
    case `type`: ActorMessageType
    of amQuit:
      discard
    of amMsg:
      msg: T
      timeout: int
  Actor*[T,S] = ref ActorObj[T,S]
  ActorPtr*[T,S] = ptr ActorObj[T,S]
  ActorThreadArgs[T,S] = object
    actor: ActorPtr[T,S]
    handler: ActorHandlerS[T,S]
    initialState: S
  ActorObj[T,S] = object of RootObj
    ## The actor type. Actors are always typed
    channel: Channel[ActorMessage[T]]
    handler: ActorHandlerS[T,S]
    name: string
    thread: Thread[ActorThreadArgs[T,S]]

proc mkAmQuit[T](): ActorMessage[T] = ActorMessage[T](`type`: amQuit)

proc mkAmMsg[T](msg: T, timeout = 0): ActorMessage[T] = ActorMessage[T](`type`: amMsg, msg: msg, timeout: timeout)

template ActorPtrT*(T: untyped): untyped =
  var x: T
  type(x[].addr)

proc initActor*[T,S](actor: var Actor[T,S], handler: ActorHandlerS[T,S]): ActorPtr[T,S] {.discardable, raises: [].} =
  new actor
  open(actor.channel)
  actor.handler = handler
  actor.name = ""
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

proc actorThread[T,S](args: ActorThreadArgs[T,S]) {.thread, nimcall.} =
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
      var mmsg = channel[].tryRecv()
      if mmsg.dataAvailable:
        let am = mmsg.msg
        case am.`type`
        of amQuit:
          cont = false
        of amMsg:
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
    a.thread.createThread(actorThread, ActorThreadArgs[T,S](actor: addr a[], handler: a.handler, initialState: initialState))
    ()

proc start*[T](a: Actor[T,Unit]): EitherS[Unit] =
  a.start(())

proc sendImpl[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: ActorMessage[T]): EitherS[Unit] {.discardable.} =
  tryS do -> auto:
    a.channel.send(msg)
    ()

proc stop*[T,S](a: Actor[T,S]): EitherS[Unit] =
  a.sendImpl(mkAmQuit[T]())

proc join*[T,S](a: Actor[T,S]): EitherS[Unit] =
  tryS do() -> auto:
    a.thread.joinThread
    ()

proc send*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T): EitherS[Unit] {.discardable.} =
  a.sendImpl(mkAmMsg(msg))

proc `!`*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T): EitherS[Unit] {.discardable.} =
  a.send(msg)

proc sendDeferred*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T, timeout: int): EitherS[Unit] {.discardable.} =
  a.sendImpl(mkAmMsg(msg, timeout))
