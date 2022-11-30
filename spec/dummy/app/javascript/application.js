import {consumer} from "./channels/consumer";

function compareId(prev, next) {
    const [ts_prev, c_prev] = prev.split("-");
    const [ts_next, c_next] = next.split("-");

    if (Number(ts_prev) > Number(ts_next)) {
        return -1;
    }

    if (Number(ts_prev) < Number(ts_next)) {
        return 1;
    }

    if (Number(ts_prev) === Number(ts_next)) {
        if (Number(c_prev) > Number(c_next)) {
            return -1;
        }

        if (Number(c_prev) < Number(c_next)) {
            return 1;
        }
    }

    return 0;
}

consumer.subscriptions.create({channel: "MessageChannel", id: "1"}, {
    buffer: [],

    connected() {
        this.intervalId = setInterval(() => {
            const data = [0, 1, 2, 3];
            this.buffer.push([0, 1, 2, 3])
            this.perform("message", {data: [0, 1, 2, 3]});
        }, 5000);

        this.lastAckId = null;
    },

    received(data) {
        // todo: when we receive a message, we acknowledge the retrieval of the
        // message.
        this.lastAckId = data.last_id;
        this.perform("ack_message", {last_id: this.lastAckId});
    },

    disconnected() {
        clearInterval(this.intervalId);
    }
});
