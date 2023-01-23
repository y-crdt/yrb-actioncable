import { Doc } from 'yjs';
import { publish, subscribe, unsubscribe } from 'lib0/broadcastchannel';
import {
  Encoder,
  createEncoder,
  length as encodingLength,
  toUint8Array,
  writeVarUint,
  writeVarUint8Array,
} from 'lib0/encoding';
import {
  Decoder,
  createDecoder,
  readVarUint,
  readVarUint8Array,
} from 'lib0/decoding';
import {
  messageYjsSyncStep2,
  readSyncMessage,
  writeSyncStep1,
  writeSyncStep2,
  writeUpdate,
} from 'y-protocols/sync';
import {
  Awareness,
  applyAwarenessUpdate,
  encodeAwarenessUpdate,
  removeAwarenessStates,
} from 'y-protocols/awareness';
import { readAuthMessage } from 'y-protocols/auth';

type MessageHandler = (
  encoder: Encoder,
  decoder: Decoder,
  provider: WebsocketProvider,
  emitSynced: boolean,
  messageType: MessageType
) => void;

export enum MessageType {
  Sync = 0,
  Awareness = 1,
  Auth = 2,
  QueryAwareness = 3,
}

type MessageHandlers = Record<MessageType, MessageHandler>;

const permissionDeniedHandler = (
  provider: WebsocketProvider,
  reason: string
) => {
  console.warn(
    `Permission denied to access ${provider.channelName}.\n${reason}`
  );
};

const messageHandlers: MessageHandlers = {
  [MessageType.Sync]: (encoder, decoder, provider, emitSynced) => {
    writeVarUint(encoder, MessageType.Sync);
    const syncMessageType = readSyncMessage(
      decoder,
      encoder,
      provider.doc,
      provider
    );
    if (
      emitSynced &&
      syncMessageType === messageYjsSyncStep2 &&
      !provider.synced
    ) {
      provider.synced = true;
    }
  },
  [MessageType.QueryAwareness]: (
    encoder,
    _decoder,
    provider,
    _emitSynced,
    _messageType
  ) => {
    writeVarUint(encoder, MessageType.Awareness);
    writeVarUint8Array(
      encoder,
      encodeAwarenessUpdate(
        provider.awareness,
        Array.from(provider.awareness.getStates().keys())
      )
    );
  },
  [MessageType.Awareness]: (_encoder, decoder, provider) => {
    applyAwarenessUpdate(
      provider.awareness,
      readVarUint8Array(decoder),
      provider
    );
  },
  [MessageType.Auth]: (_encoder, decoder, provider) => {
    readAuthMessage(decoder, provider.doc, (_ydoc, reason) =>
      permissionDeniedHandler(provider, reason)
    );
  },
};

export class WebsocketProvider {
  readonly consumer: ActionCable.Cable;
  channel: ActionCable.Channel | undefined;
  readonly params: Record<string, string>;
  readonly doc: Doc;
  readonly channelName: string;
  readonly awareness: Awareness;
  bcconnected: boolean;
  private readonly disableBc: boolean;
  private _synced: boolean;

  constructor(
    doc: Doc,
    consumer: ActionCable.Cable,
    channel: string,
    params: Record<string, string>,
    { awareness = new Awareness(doc), disableBc = false } = {}
  ) {
    this.consumer = consumer;
    this.channelName = channel;
    this.params = params;
    this.doc = doc;
    this.awareness = awareness;
    this.bcconnected = false;
    this.disableBc = disableBc;
    this._synced = false;

    this.doc.on('update', this.updateHandler);

    if (typeof window !== 'undefined') {
      window.addEventListener('unload', this.unloadHandler);
    } else if (typeof process !== 'undefined') {
      process.on('exit', this.unloadHandler);
    }

    awareness.on('update', this.awarenessUpdateHandler);

    this.connect();
  }

  private bcSubscriber = (data: any, origin: any) => {
    if (origin !== this) {
      const encoder = this.process(new Uint8Array(data), false);
      if (encodingLength(encoder) > 1) {
        publish(this.channelName, toUint8Array(encoder), this);
      }
    }
  };

  private updateHandler = (update: Uint8Array, origin: any) => {
    if (origin !== this) {
      const encoder = createEncoder();
      writeVarUint(encoder, MessageType.Sync);
      writeUpdate(encoder, update);
      this.send(toUint8Array(encoder));
    }
  };

  private unloadHandler = () => {
    removeAwarenessStates(this.awareness, [this.doc.clientID], 'window unload');
  };

  private awarenessUpdateHandler = (
    {
      added,
      updated,
      removed,
    }: { added: Array<any>; updated: Array<any>; removed: Array<any> },
    _origin: any
  ) => {
    const changedClients = added.concat(updated).concat(removed);
    const encoder = createEncoder();
    writeVarUint(encoder, MessageType.Awareness);
    writeVarUint8Array(
      encoder,
      encodeAwarenessUpdate(this.awareness, changedClients)
    );
    this.send(toUint8Array(encoder));
  };

  get synced() {
    return this._synced;
  }

  set synced(state) {
    if (this._synced !== state) {
      this._synced = state;
    }
  }

  destroy() {
    this.disconnect();
    if (typeof window !== 'undefined') {
      window.removeEventListener('unload', this.unloadHandler);
    } else if (typeof process !== 'undefined') {
      process.off('exit', this.unloadHandler);
    }

    this.awareness.off('update', this.awarenessUpdateHandler);
    this.doc.off('update', this.updateHandler);
  }

  private send(buffer: Uint8Array) {
    const update = encodeBinaryToBase64(buffer);
    this.channel?.send({ update });

    if (this.bcconnected) {
      publish(this.channelName, buffer, this);
    }
  }

  private process(buffer: Uint8Array, emitSynced: boolean) {
    const decoder = createDecoder(buffer);
    const encoder = createEncoder();
    const messageType = readVarUint(decoder) as MessageType;
    const messageHandler = messageHandlers[messageType];
    if (messageHandler) {
      messageHandler(encoder, decoder, this, emitSynced, messageType);
    } else {
      console.error('Unable to compute message');
    }
    return encoder;
  }

  private subscribe() {
    const provider = this;

    this.synced = false;
    this.channel = this.consumer.subscriptions.create(
      { channel: this.channelName, ...this.params },
      {
        received(message: { update: string }) {
          const { update: encodedUpdate } = message;
          const update = decodeBase64ToBinary(encodedUpdate);
          const encoder = provider.process(update, true);
          if (encodingLength(encoder) > 1) {
            provider.send(toUint8Array(encoder));
          }
        },
        disconnected() {
          provider.synced = false;
          // update awareness (all users except local left)
          removeAwarenessStates(
            provider.awareness,
            Array.from(provider.awareness.getStates().keys()).filter(
              client => client !== provider.doc.clientID
            ),
            provider
          );
        },
        connected() {
          // always send sync step 1 when connected
          const encoder = createEncoder();
          writeVarUint(encoder, MessageType.Sync);
          writeSyncStep1(encoder, provider.doc);
          provider.send(toUint8Array(encoder));
          // broadcast local awareness state
          if (provider.awareness.getLocalState() !== null) {
            const encoderAwarenessState = createEncoder();
            writeVarUint(encoderAwarenessState, MessageType.Awareness);
            writeVarUint8Array(
              encoderAwarenessState,
              encodeAwarenessUpdate(provider.awareness, [provider.doc.clientID])
            );

            provider.send(toUint8Array(encoderAwarenessState));
          }
        },
      }
    );
  }

  private connectBc() {
    if (this.disableBc) {
      return;
    }

    if (!this.bcconnected) {
      subscribe(this.channelName, this.bcSubscriber);
      this.bcconnected = true;
    }

    // send sync step1 to bc
    // write sync step 1
    const encoderSync = createEncoder();
    writeVarUint(encoderSync, MessageType.Sync);
    writeSyncStep1(encoderSync, this.doc);
    publish(this.channelName, toUint8Array(encoderSync), this);

    // broadcast local state
    const encoderState = createEncoder();
    writeVarUint(encoderState, MessageType.Sync);
    writeSyncStep2(encoderState, this.doc);
    publish(this.channelName, toUint8Array(encoderState), this);

    // write queryAwareness
    const encoderAwarenessQuery = createEncoder();
    writeVarUint(encoderAwarenessQuery, MessageType.QueryAwareness);
    publish(this.channelName, toUint8Array(encoderAwarenessQuery), this);

    // broadcast local awareness state
    const encoderAwarenessState = createEncoder();
    writeVarUint(encoderAwarenessState, MessageType.Awareness);
    writeVarUint8Array(
      encoderAwarenessState,
      encodeAwarenessUpdate(this.awareness, [this.doc.clientID])
    );
    publish(this.channelName, toUint8Array(encoderAwarenessState), this);
  }

  private disconnectBc() {
    // broadcast message with local awareness state set to null (indicating disconnect)
    const encoder = createEncoder();
    writeVarUint(encoder, MessageType.Awareness);
    writeVarUint8Array(
      encoder,
      encodeAwarenessUpdate(this.awareness, [this.doc.clientID], new Map())
    );
    this.send(toUint8Array(encoder));
    if (this.bcconnected) {
      unsubscribe(this.channelName, this.bcSubscriber);
      this.bcconnected = false;
    }
  }

  private disconnect() {
    this.disconnectBc();
    this.channel?.unsubscribe();
    if (this.channel != null) {
      this.channel = undefined;
    }
  }

  private connect() {
    if (this.channel == null) {
      this.subscribe();
      this.connectBc();
    }
  }
}

function encodeBinaryToBase64(bin: Uint8Array) {
  const chars = Array.from(bin, ch => String.fromCharCode(ch)).join('');
  return btoa(chars);
}

function decodeBase64ToBinary(update: string) {
  return Uint8Array.from(atob(update), c => c.charCodeAt(0));
}
