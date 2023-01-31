# yrb-actioncable

> A WebSocket provider for Y.js that works with ActionCable

## Installation

With npm:

```bash
npm install @y-rb/actioncable
```

With yarn:

```bash
yarn add @y-rb/actioncable --save
```

## Usage

```typescript
import {Doc} from "yjs";
import {WebsocketProvider} from "@y-rb/actioncable";
import {createConsumer} from "@rails/actioncable";

const document = new Doc();
const consumer = createConsumer();
const provider = new WebsocketProvider(
  document,
  consumer,
  "SyncChannel",
  {path: "issues/1"}
);
```
