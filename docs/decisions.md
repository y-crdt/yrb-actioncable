# 2022-10-13 Append only log

Instead of Redis Pub/Sub mechanism, we use Redis Streams to conceptually
establish a message queue system. This allows us to get eventual consistency
on all clients.
