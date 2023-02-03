import * as map from 'lib0/map';

/**
 * Helpers for cross-tab communication using broadcastchannel with LocalStorage
 * fallback. This is a copy of
 * https://github.com/dmonad/lib0/blob/main/broadcastchannel.js that does not
 * fall back to LocalStore to prevent SSR issues.
 *
 * ```js
 * // In browser window A:
 * broadcastchannel.subscribe('my events', data => console.log(data))
 * broadcastchannel.publish('my events', 'Hello world!') // => A: 'Hello world!' fires synchronously in same tab
 *
 * // In browser window B:
 * broadcastchannel.publish('my events', 'hello from tab B') // => A: 'hello from tab B'
 * ```
 */

const channels = new Map();

type Sub = (e: MessageEvent, origin: any) => void;

const getChannel = (room: string) =>
  map.setIfUndefined(channels, room, () => {
    const subs = new Set<Sub>();
    const bc = new BroadcastChannel(room);

    bc.onmessage = e => {
      subs.forEach((sub: Sub) => {
        sub(e.data, 'broadcastchannel');
      });
    };

    return {
      bc,
      subs,
    };
  });

export const subscribe = (
  room: string,
  f: (data: any, origin: any) => void
) => {
  getChannel(room).subs.add(f);

  return f;
};

export const unsubscribe = (room: string, f: any) => {
  const channel = getChannel(room);
  const unsubscribed = channel.subs.delete(f);
  /* istanbul ignore else */
  if (unsubscribed && channel.subs.size === 0) {
    channel.bc.close();
    channels.delete(room);
  }
  return unsubscribed;
};

export const publish = (room: string, data: any, origin: any = null) => {
  const c = getChannel(room);
  c.bc.postMessage(data);
  c.subs.forEach((sub: Sub) => sub(data, origin));
};
