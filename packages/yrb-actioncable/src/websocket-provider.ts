import { Doc } from 'yjs';
import * as awarenessProtocol from 'y-protocols/awareness';
import * as encoding from 'lib0/dist/encoding';
import * as bc from 'lib0/dist/broadcastchannel';
import * as syncProtocol from 'y-protocols/sync';
import * as decoding from 'lib0/decoding';

import { messageHandlers } from './handlers';
import { MessageType } from './message-type';

export class WebsocketProvider {
  readonly consumer: ActionCable.Cable;
  channel: ActionCable.Channel | undefined;
  readonly params: Record<string, string>;
  readonly doc: Doc;
  readonly channelName: string;
  readonly awareness: awarenessProtocol.Awareness;
  bcconnected: boolean;
  private readonly disableBc: boolean;

  private _checkInterval: number | undefined;
  private _resyncInterval: number | undefined;
  private _synced: boolean;

  constructor(
    doc: Doc,
    consumer: ActionCable.Cable,
    channel: string,
    params: Record<string, string>,
    { awareness = new awarenessProtocol.Awareness(doc), disableBc = false } = {}
  ) {
    this.consumer = consumer;
    this.channelName = channel;
    this.params = params;
    this.doc = doc;
    this.awareness = awareness;
    this.bcconnected = false;
    this.disableBc = disableBc;
    this._synced = false;

    this.doc.on('update', this._updateHandler);

    if (typeof window !== 'undefined') {
      window.addEventListener('unload', this._unloadHandler);
    } else if (typeof process !== 'undefined') {
      process.on('exit', this._unloadHandler);
    }

    awareness.on('update', this._awarenessUpdateHandler);

    this.connect();
  }

  private _bcSubscriber = (data: any, origin: any) => {
    if (origin !== this) {
      const encoder = this.process(new Uint8Array(data), false);
      if (encoding.length(encoder) > 1) {
        bc.publish(this.channelName, encoding.toUint8Array(encoder), this);
      }
    }
  };

  private _updateHandler = (update: Uint8Array, origin: any) => {
    if (origin !== this) {
      const encoder = encoding.createEncoder();
      encoding.writeVarUint(encoder, MessageType.Sync);
      syncProtocol.writeUpdate(encoder, update);
      this.broadcast(encoding.toUint8Array(encoder));
    }
  };

  private _unloadHandler = () => {
    awarenessProtocol.removeAwarenessStates(
      this.awareness,
      [this.doc.clientID],
      'window unload'
    );
  };

  private _awarenessUpdateHandler = (
    {
      added,
      updated,
      removed,
    }: { added: Array<any>; updated: Array<any>; removed: Array<any> },
    _origin: any
  ) => {
    const changedClients = added.concat(updated).concat(removed);
    const encoder = encoding.createEncoder();
    encoding.writeVarUint(encoder, MessageType.Awareness);
    encoding.writeVarUint8Array(
      encoder,
      awarenessProtocol.encodeAwarenessUpdate(this.awareness, changedClients)
    );
    this.broadcast(encoding.toUint8Array(encoder));
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
    if (this._resyncInterval != null) {
      clearInterval(this._resyncInterval);
    }
    clearInterval(this._checkInterval);
    this.disconnect();
    if (typeof window !== 'undefined') {
      window.removeEventListener('unload', this._unloadHandler);
    } else if (typeof process !== 'undefined') {
      process.off('exit', this._unloadHandler);
    }

    this.awareness.off('update', this._awarenessUpdateHandler);
    this.doc.off('update', this._updateHandler);
  }

  private broadcast(buffer: Uint8Array) {
    this.channel?.send({ data: Array.from(buffer) });

    if (this.bcconnected) {
      bc.publish(this.channelName, buffer, this);
    }
  }

  private process(buffer: Uint8Array, emitSynced: boolean) {
    const decoder = decoding.createDecoder(buffer);
    const encoder = encoding.createEncoder();
    const messageType = decoding.readVarUint(decoder) as MessageType;
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
        received({ data }: any) {
          const encoder = provider.process(new Uint8Array(data), true);
          if (encoding.length(encoder) > 1) {
            this.send({ data: Array.from(encoding.toUint8Array(encoder)) });
          }
        },
        disconnected() {
          provider.synced = false;
          // update awareness (all users except local left)
          awarenessProtocol.removeAwarenessStates(
            provider.awareness,
            Array.from(provider.awareness.getStates().keys()).filter(
              client => client !== provider.doc.clientID
            ),
            provider
          );
        },
        connected() {
          // always send sync step 1 when connected
          const encoder = encoding.createEncoder();
          encoding.writeVarUint(encoder, MessageType.Sync);
          syncProtocol.writeSyncStep1(encoder, provider.doc);
          this.send({ data: Array.from(encoding.toUint8Array(encoder)) });
          // broadcast local awareness state
          if (provider.awareness.getLocalState() !== null) {
            const encoderAwarenessState = encoding.createEncoder();
            encoding.writeVarUint(encoderAwarenessState, MessageType.Awareness);
            encoding.writeVarUint8Array(
              encoderAwarenessState,
              awarenessProtocol.encodeAwarenessUpdate(provider.awareness, [
                provider.doc.clientID,
              ])
            );
            this.send({
              data: Array.from(encoding.toUint8Array(encoderAwarenessState)),
            });
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
      bc.subscribe(this.channelName, this._bcSubscriber);
      this.bcconnected = true;
    }

    // send sync step1 to bc
    // write sync step 1
    const encoderSync = encoding.createEncoder();
    encoding.writeVarUint(encoderSync, MessageType.Sync);
    syncProtocol.writeSyncStep1(encoderSync, this.doc);
    bc.publish(this.channelName, encoding.toUint8Array(encoderSync), this);

    // broadcast local state
    const encoderState = encoding.createEncoder();
    encoding.writeVarUint(encoderState, MessageType.Sync);
    syncProtocol.writeSyncStep2(encoderState, this.doc);
    bc.publish(this.channelName, encoding.toUint8Array(encoderState), this);

    // write queryAwareness
    const encoderAwarenessQuery = encoding.createEncoder();
    encoding.writeVarUint(encoderAwarenessQuery, MessageType.QueryAwareness);
    bc.publish(
      this.channelName,
      encoding.toUint8Array(encoderAwarenessQuery),
      this
    );

    // broadcast local awareness state
    const encoderAwarenessState = encoding.createEncoder();
    encoding.writeVarUint(encoderAwarenessState, MessageType.Awareness);
    encoding.writeVarUint8Array(
      encoderAwarenessState,
      awarenessProtocol.encodeAwarenessUpdate(this.awareness, [
        this.doc.clientID,
      ])
    );
    bc.publish(
      this.channelName,
      encoding.toUint8Array(encoderAwarenessState),
      this
    );
  }

  private disconnectBc() {
    // broadcast message with local awareness state set to null (indicating disconnect)
    const encoder = encoding.createEncoder();
    encoding.writeVarUint(encoder, MessageType.Awareness);
    encoding.writeVarUint8Array(
      encoder,
      awarenessProtocol.encodeAwarenessUpdate(
        this.awareness,
        [this.doc.clientID],
        new Map()
      )
    );
    this.broadcast(encoding.toUint8Array(encoder));
    if (this.bcconnected) {
      bc.unsubscribe(this.channelName, this._bcSubscriber);
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
