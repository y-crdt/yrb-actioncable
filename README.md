<p align="center">
  <img alt="Yrb" src="./docs/assets/logo.png" width="300" />
</p>

---

# yrb-actioncable

> An ActionCable companion for Y.js clients

This is a monorepo with [npm modules](./packages) and [Ruby gems](./gems).
Please check the respective sub-repos for more information. 

## Usage

Install gem and npm package:

```
gem install y-rb_actioncable
yarn add @y-rb/actioncable
```

Create a Rails channel that includes the Sync module:

```ruby
# app/channels/sync_channel.rb
class SyncChannel < ApplicationCable::Channel
  include Y::Actioncable::Sync

  def subscribed
    # initiate sync & subscribe to updates, with optional persistence mechanism
    stream_for(session)
  end

  def receive(message)
    # broadcast update to all connected clients on all servers
    sync_to(session, message)
  end
end
```

Create a client and bind to an editor (tiptap) instance:

```typescript
import {WebsocketProvider} from "@y-rb/actioncable";
import { createConsumer } from "@rails/actioncable";

const document = new Y.Doc();
const consumer = createConsumer();

const provider = new WebsocketProvider(
  document,
  consumer,
  "SyncChannel",
  {id: "1"}
);

new Editor({
  element: document.querySelector("#editor"),
  extensions: [
    StarterKit.configure({history: false}),
    Collaboration.configure({document}),
    CollaborationCursor.configure({
      provider,
      user: {name: "Hannes", color: "#ff0000"}
    })
  ]
});
```

## License

The gem is available as *open source* under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
