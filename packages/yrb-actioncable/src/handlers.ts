import * as encoding from 'lib0/dist/encoding';
import * as syncProtocol from 'y-protocols/sync';
import * as awarenessProtocol from 'y-protocols/awareness';
import * as decoding from 'lib0/decoding';
import * as authProtocol from 'y-protocols/auth';
import { WebsocketProvider } from './websocket-provider';
import { MessageType } from './message-type';

type MessageHandler = (
  encoder: encoding.Encoder,
  decoder: decoding.Decoder,
  provider: WebsocketProvider,
  emitSynced: boolean,
  messageType: MessageType
) => void;

type MessageHandlers = Record<MessageType, MessageHandler>;

const permissionDeniedHandler = (
  provider: WebsocketProvider,
  reason: string
) => {
  console.warn(
    `Permission denied to access ${provider.channelName}.\n${reason}`
  );
};

export const messageHandlers: MessageHandlers = {
  [MessageType.Sync]: (encoder, decoder, provider, emitSynced) => {
    encoding.writeVarUint(encoder, MessageType.Sync);
    const syncMessageType = syncProtocol.readSyncMessage(
      decoder,
      encoder,
      provider.doc,
      provider
    );
    if (
      emitSynced &&
      syncMessageType === syncProtocol.messageYjsSyncStep2 &&
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
    encoding.writeVarUint(encoder, MessageType.Awareness);
    encoding.writeVarUint8Array(
      encoder,
      awarenessProtocol.encodeAwarenessUpdate(
        provider.awareness,
        Array.from(provider.awareness.getStates().keys())
      )
    );
  },
  [MessageType.Awareness]: (_encoder, decoder, provider) => {
    awarenessProtocol.applyAwarenessUpdate(
      provider.awareness,
      decoding.readVarUint8Array(decoder),
      provider
    );
  },
  [MessageType.Auth]: (_encoder, decoder, provider) => {
    authProtocol.readAuthMessage(decoder, provider.doc, (_ydoc, reason) =>
      permissionDeniedHandler(provider, reason)
    );
  },
};
