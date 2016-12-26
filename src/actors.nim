import fp,
       boost.types,
       asyncdispatch

type
  ActorHandler*[T] = proc(self: ActorPtr[T], msg: T): bool {.gcsafe.}
  ActorMessage = enum amQuit
  Actor*[T] = ref ActorObj[T]
  ActorPtr*[T] = ptr ActorObj[T]
  ActorThreadArgs[T] = object
    actor: ActorPtr[T]
  ActorObj[T] = object
    ## The actor type. Actors are always typed
    channel: Channel[Either[ActorMessage, T]]
    handler: ActorHandler[T]
    name: string
    thread: Thread[ActorThreadArgs[T]]

proc initActor*[T](actor: var Actor[T], handler: ActorHandler[T]): ActorPtr[T] {.discardable, raises: [].} =
  new actor
  open(actor.channel)
  actor.handler = handler
  actor.name = ""
  actor[].addr

proc initActor*[T](handler: ActorHandler[T]): Actor[T] {.raises: [].} =
  discard initActor(result, handler)

proc setName*[T](a: Actor[T], name: string): Actor[T] {.discardable, raises: [].} =
  a.name = name
  result = a

proc handleActorMessage(a: ActorMessage): bool =
  result = true
  if a == amQuit:
    result = false

proc actorThread[T](args: ActorThreadArgs[T]) {.thread, nimcall.} =
  let channel = addr args.actor[].channel
  let handler = args.actor[].handler
  while true:
    poll(0)
    var mmsg = channel[].tryRecv()
    if mmsg.dataAvailable:
      if mmsg.msg.isLeft and not handleActorMessage(mmsg.msg.getLeft):
        return
      else:
        if not handler(args.actor, mmsg.msg.get):
          return

proc start*[T](a: Actor[T]): EitherS[Unit] =
  flatTryS do() -> auto:
    if a.thread.running:
      "The actor is already running".left(Unit)
    else:
      a.thread.createThread(actorThread, ActorThreadArgs[T](actor: addr a[]))
      ().rightS

proc stop*[T](a: Actor[T]): EitherS[Unit] =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do -> auto:
      a.channel.send(amQuit.left(T))
      ()

proc join*[T](a: Actor[T]): EitherS[Unit] =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do() -> auto:
      a.thread.joinThread
      ()

proc `!`*[T](a: Actor[T]|ActorPtr[T], msg: T): EitherS[Unit] {.discardable.} =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do -> auto:
      a.channel.send(msg.right(ActorMessage))
      ()
