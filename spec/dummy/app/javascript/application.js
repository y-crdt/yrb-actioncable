import {consumer} from "./channels/consumer";

function compareId(prev, next) {
  const [ts_prev, c_prev] = prev.split("-").map(n => Number(n));
  const [ts_next, c_next] = next.split("-").map(n => Number(n));

  if (ts_prev > ts_next) {
    return -1;
  }

  if (ts_prev < ts_next) {
    return 1;
  }

  if (ts_prev === ts_next) {
    if (c_prev > c_next) {
      return -1;
    }

    if (c_prev < c_next) {
      return 1;
    }
  }

  return 0;
}

class ReliableSender {
  #buffer
  #clock
  #channel
  #id
  #subscription

  constructor(channel, id) {
    this.channel = channel;
    this.id = id;
    this.clock = -1;
    this.buffer = [];

    let that = this;
    this.#subscription = consumer.subscriptions.create({channel, id}, {
      received(data) {
        const {clock, data, last_id} = data;
        that.setClock(clock);
        that.trim()
      }
    });
  }

  /**
   * Try to send a new data packet to the server
   * @param data
   */
  send(data) {
    // store data in buffer with increased clock
    this.buffer.push(new ReliableMessage(data, ++this.clock));

    // send message

  }

  ack(action, lastId) {
    this.#subscription.perform(`ack_${action}`, {last_id: lastId})
  }

  received(data) {

  }

  /**
   * Set clock to new tick if the new value is greater than the previous value
   *
   * @param tick
   * @return void
   */
  setClock(tick) {
    if (tick > this.clock) {
      this.clock = tick;
    }
  }

  /**
   * Trim buffer by removing messages that are < current clock value
   * @return @void
   */
  trim() {
    // Find the (inclusive) index of up to where we know that transmission was
    // successful (acknowledged by server).
    const deleteUpTo = this.buffer.findIndex((message) => message.clock === this.clock);

    // do nothing if we can't find an index that matches
    if (deleteUpTo === -1) {
      return;
    }

    // delete up to and including the index we found in the previous step
    this.buffer.splice(0, deleteUpTo + 1);
  }
}

class ReliableMessage {
  constructor(data, clock) {
    this.data = data;
    this.clock = clock;
  }
}

const sender = new ReliableSender("MessageChannel", "1");
setInterval(() => sender.send([0, 1, 2, 3]), 5000);
