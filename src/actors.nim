import fp,
       boost.types,
       asyncdispatch

type
  ActorHandlerS*[T,S] = proc(self: ActorPtr[T,S], msg: T, state: S): Option[S] {.gcsafe.}
  ActorHandler*[T] = proc(self: ActorPtr[T,Unit], msg: T): bool {.gcsafe.}
  ActorMessage = enum amQuit
  Actor*[T,S] = ref ActorObj[T,S]
  ActorPtr*[T,S] = ptr ActorObj[T,S]
  ActorThreadArgs[T,S] = object
    actor: ActorPtr[T,S]
    initialState: S
  ActorObj[T,S] = object of RootObj
    ## The actor type. Actors are always typed
    channel: Channel[Either[ActorMessage, T]]
    handler: ActorHandlerS[T,S]
    name: string
    thread: Thread[ActorThreadArgs[T,S]]

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

proc handleActorMessage(a: ActorMessage): bool =
  result = true
  if a == amQuit:
    result = false

proc actorThread[T,S](args: ActorThreadArgs[T,S]) {.thread, nimcall.} =
  let channel = addr args.actor[].channel
  let handler = args.actor[].handler
  var state = args.initialState
  try:
    while true:
      poll(0)
      var mmsg = channel[].tryRecv()
      if mmsg.dataAvailable:
        if mmsg.msg.isLeft and not handleActorMessage(mmsg.msg.getLeft):
          return
        else:
          let so = handler(args.actor, mmsg.msg.get, state)
          if so.isDefined:
            state = so.get
          else:
            return
  except:
    #TODO: We need a channel for result
    discard

proc start*[T,S](a: Actor[T,S], initialState: S): EitherS[Unit] =
  tryS do() -> auto:
    a.thread.createThread(actorThread, ActorThreadArgs[T,S](actor: addr a[], initialState: initialState))
    ()

proc stop*[T,S](a: Actor[T,S]): EitherS[Unit] =
  tryS do -> auto:
    a.channel.send(amQuit.left(T))
    ()

proc join*[T,S](a: Actor[T,S]): EitherS[Unit] =
  tryS do() -> auto:
    a.thread.joinThread
    ()

proc `!`*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T): EitherS[Unit] {.discardable.} =
  tryS do -> auto:
    a.channel.send(msg.right(ActorMessage))
    ()
