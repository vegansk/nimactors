import fp,
       boost.types,
       asyncdispatch

type
  ActorHandler*[T,S] = proc(self: ActorPtr[T,S], msg: T, state: S): Option[S] {.gcsafe.}
  ActorMessage = enum amQuit
  Actor*[T,S] = ref ActorObj[T,S]
  ActorPtr*[T,S] = ptr ActorObj[T,S]
  ActorThreadArgs[T,S] = object
    actor: ActorPtr[T,S]
    initialState: S
  ActorObj[T,S] = object of RootObj
    ## The actor type. Actors are always typed
    channel: Channel[Either[ActorMessage, T]]
    handler: ActorHandler[T,S]
    name: string
    thread: Thread[ActorThreadArgs[T,S]]

proc initActor*[T,S](actor: var Actor[T,S], handler: ActorHandler[T,S]): ActorPtr[T,S] {.discardable, raises: [].} =
  new actor
  open(actor.channel)
  actor.handler = handler
  actor.name = ""
  actor[].addr

proc initActor*[T,S](handler: ActorHandler[T,S]): Actor[T,S] {.raises: [].} =
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

proc start*[T,S](a: Actor[T,S], initialState: S): EitherS[Unit] =
  flatTryS do() -> auto:
    if a.thread.running:
      "The actor is already running".left(Unit)
    else:
      a.thread.createThread(actorThread, ActorThreadArgs[T,S](actor: addr a[], initialState: initialState))
      ().rightS

proc stop*[T,S](a: Actor[T,S]): EitherS[Unit] =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do -> auto:
      a.channel.send(amQuit.left(T))
      ()

proc join*[T,S](a: Actor[T,S]): EitherS[Unit] =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do() -> auto:
      a.thread.joinThread
      ()

proc `!`*[T,S](a: Actor[T,S]|ActorPtr[T,S], msg: T): EitherS[Unit] {.discardable.} =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do -> auto:
      a.channel.send(msg.right(ActorMessage))
      ()
