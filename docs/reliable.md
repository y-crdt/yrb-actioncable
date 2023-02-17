# Reliable Sync

The state of any CRDT instance is eventually consistent with all the other
instances. If we miss one or more updates, we can't be sure that all the
instances eventually converge to the same state. This is not a feature of the
default *ActionCable* implementation in Rails. Therefore, we built a mechanism
that guarantees `at-least-once` delivery and builds on top of Rails ActionCable.

`yrb-actioncable` extends ActionCable with a sync and a reliable sync mechanism.
The following document describes the parts that make a sync reliable. In order
to be considered an (effective) reliable transport, it must provide the
following features:

- `at-least-once` delivery of new updates from any client
- `at-least-once` distribution of updates from the server
- No delays in the delivery of messages (happy path)

This extension does not provide any order guarantees. This is ok, due to
integrating updates in a Y.js document is idempotent, and applying the same
update multiple times will not change the state.

In order to achieve the guarantees described above, we must maintain a message
queue that is not only capable of distributing messages to clients considered
_live_. ActionCable relies on Redis PubSub, which only guarantees `at-most-once`
delivery, and it is possible that messages get dropped (temporary disconnect,
node crashing, …).

To work around these limitations, we use the concept of _Streams_. Every unique
document must maintain its own _stream_ of updates. A stream is an append-only
data-structure, and once an update is appended, it becomes immutable.

We guarantee that an update is appended to a _stream_, by `acknowledging` the
retrieval and persistence of the update in the stream. In case a message does
not get acknowledged, we will make sure to send the message again. We retry as
long as necessary for a message to get acknowledged.

It is  important to understand, that the client and server implementation
are different. As there are many clients and (conceptually) one server, it is
far more important that all updates produced by any client eventually end up on
the server to be re-distributed to all other clients immediately, than one
client missing an update from the server (as long as the client catches up
eventually).
Therefore, there is a relatively small timespan for the server to acknowledge
message retrieval, before a client tries again. The client must implement an
exponential backoff mechanism with a maximum number of retries to not overwhelm
the server, and it must eventually stop trying when maximum number of retries is
reached. At this point a client can be considered offline and need to
essentially resync it's complete state to the server to be considered online
again.

Instead, when a client does not immediately acknowledge an update distributed to
it, the server does not retry immediately, but instead tracks the current
offset of the client in the stream. This is conceptually similar to how
consumers and consumer groups work in Kafka and Redis Streams.

## Tracker

A tracker is implemented as a sorted set. The sort order (score) is the
normalized stream offset of a client. In case of Redis, this is a padded
Integer, created from the `entry_id` returned by invoking the `#xadd` method.

The `entry_id` returned by the `stream` append operation is guaranteed to be a
monotonic counter. As we cannot sort on the provided format, we pad the
right-side counter with enough space to be sure that there is never going to be
a conflict. In order for this format to break, a client would need to produce
more than 999 messages within `1 ms`.

```
entry_id = client.xadd(…) # 123456-0 -> 123456000
entry_id = client.xadd(…) # 123456-1 -> 123456001
```

The item that is tracked is not the user object, but the connection. This is
necessary to support scenarios where a user has multiple browsers or tabs open
with the same document.

A connection is added to the tracker as soon as a connection `subscribes` to a
`channel`, and a `channel` must always have a `1:1` relation with a `Document`.
The connection will be removed from the tracker as soon as the connection gets
dropped (`unsubsribed`).

## Garbage Collection

The _reliable_ sync mechanism adds state to the server, just for the purpose of
guaranteeing delivery. When not being careful, memory usage can balloon easily
for both, the stream and the tracker. The assumption is that the volume of
updates grows linear with the number of users. To reduce the state kept in
memory to a minimum, we use the tracker to truncate the stream, and a heuristic
to collect garbage from the tracker.

### Truncate the stream

The stream is periodically (or manually) truncated using the _minimum score_
currently stored in the tracker. This means, when all clients have acknowledged
all updates, the size of the `stream = 0`, and in return, when at least one
client hasn't acknowledged any update, the size of the
`stream = number of updates`. The actual size of the stream will vary based on
various factors:
1. Length of the _interval_ (higher values = more memory)
2. Health of clients (unhealthy clients > 0 = more memory)

### Garbage collect clients in the tracker

Due to the second scenario (at least one client does not acknowledge any
update), we need to make sure that the tracker is cleaned from clients that are
not in a healthy state. To determine if a client is not health, we use two
heuristics:

1. We assume that clients become _unhealthy_ when they fall too far behind from other clients (relative delta)
2. When clients haven't consumed any updates for a given timespan (absolute delta)

Due to the tracker being implemented as a sorted set, and given that the order
value is essentially a padded UNIX epoch, we can check for both heuristics with
low runtime complexity.

For 1): we measure the delta between the client with the highest score and all
other clients. Every client that exceeds a threshold (e.g., 30 seconds) is
evicted from the tracker. This can easily be implemented with a
`ZREMRANGEBYSCORE` in Redis. This is the only heuristic applied as long as there
is one health client.

For 2): For cases where no client is healthy, we make sure that the delta
between any client and the current server UNIX epoch is not above a certain
threshold (e.g., 30 minutes). The second threshold must be higher than the first
one and should be selected carefully based on use cases (e.g. temporary offline
for x minutes due to Wi-Fi disconnect in train). We can, again, use
`ZREMRANGEBYSCORE` to evict clients from the tracker that exceed the threshold.

## Operations

### Acknowledge

Every message exchanged between client and server is identified by an `op` type.
The `ack` operation usually consists of one field: `id`. This allows the sender
to accept a message as delivered.

For the client, this results in clearing the _send buffer_ from the acknowledged
message, and the server will update (move) the tracker offset for the client
that acknowledged given `id`.

The client retry mechanism implemented as follows:

A function is periodically called to retry any message that is still in the
_send buffer_. To let the client establish a relation between the `acknowledge`
operation payload and the actual message acknowledged by the server, we use a
logical clock instead of the stream offset when sending messages from the client
side.

The implementation uses UNIX epochs to determine if we have reached the number
of max retries. The length of the interval for the periodically called `retry`
function must exceed the maximum time that it can take for the retry mechanism
to terminate.

The server does not implement a retry mechanism, but will re-send all messages
that aren't acknowledged by a connection when a new incoming message is
distributed to a client. This results in relatively little overhead for reliable
messaging on the server-side, which should be helpful scaling the messaging
system to many clients.

### Update

Incoming updates are relayed to all clients immediately (re-broadcasted). The
update operation implements a small optimization, where it uses the identifier
of a connection to determine the `origin` of a message. The actual `transmit`
implementation then does not send a message back to its origin. This is strictly
speaking not a functional requirement, but makes the messaging more efficient
and easier to debug.
