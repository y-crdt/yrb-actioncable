# yrb-actioncable

> A WebSocket provider for Y.js that works with ActionCable

## Installation

With npm:

```bash
npm install yrb-actioncable
```

With yarn:

```bash
yarn add yrb-actioncable --save
```

## Usage

```typescript
import {Doc} from "yjs";
import {WebsocketProvider} from "yrb-actioncable";

const document = new Doc();
const provider = new WebsocketProvider(
  document,
  consumer,
  "SyncChannel",
  {path: "issues/1"}
);
```
