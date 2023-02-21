<p align="center">
  <img alt="Yrb" src="./docs/assets/logo.png" width="300" />
</p>

---

# yrb-actioncable

> An ActionCable companion for Y.js clients

This project provides you with the necessary JavaScript and Ruby dependencies to
set up a reliable WebSocket connection between many
[Y.js](https://github.com/yjs/yjs) clients and a Ruby on Rails server, using
standard Rails [ActionCable](https://guides.rubyonrails.org/action_cable_overview.html)
[channels](https://guides.rubyonrails.org/action_cable_overview.html#terminology-channels).

The project is organized as a monorepo with [npm modules](./packages) and
[Ruby gems](./gems). Please check the respective sub-repos and
[documentation](https://y-crdt.github.io/yrb-actioncable/) for detailed
information. 

## Usage

Install gem and npm package:

```
gem install y-rb_actioncable
yarn add @y-rb/actioncable
```

### Example

Create a Rails channel that includes the Sync module:

```ruby
# app/channels/sync_channel.rb
class SyncChannel < ApplicationCable::Channel
  include Y::Actioncable::Sync

  def subscribed
    # initiate sync & subscribe to updates, with optional persistence mechanism
    sync_for(session)
  end

  def receive(message)
    # broadcast update to all connected clients on all servers
    sync_to(session, message)
  end
end
```

Create a client and bind to an instance of the [tiptap](https://tiptap.dev/)
editor:

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

## Development

Make sure you have Ruby and Node.js w/ yarn installed. We recommend to manage
runtimes with [asdf](https://asdf-vm.com/).

`yrb-actioncable` is a mix of Ruby and JavaScript repositories. The JavaScript
repositories are manged with [turbo](https://turbo.build/repo).
After you have successfully run `yarn` in the repository root, _turbo_ will be
available and can be used to build packages.

### JavaScript

```bash
yarn
yarn lint:fix     # lint and autocorrect violations
yarn turbo build  # build npm package
```

Releasing a new version of an npm module is easy. We use
[changesets](https://github.com/changesets/changesets/blob/main/docs/intro-to-using-changesets.md)
to make it really simple:

```bash
# Add a new changeset
changeset

# Create new versions of packages
changeset version

# Commit and push to main
# GitHub Action will automatically create a tag, a GitHub release entry, build
# and publish the package to npmjs.com. The GitHub Action runs`yarn release`.
```

If you need to create a new package, please use [tsdx](https://tsdx.io/) for
setup. It removes a lot of the setup pain, and creates correct builds for
many targets (Node.js, ECMAScript Modules, AMD, …).

### Ruby

Ruby development is less automated. You **cannot** use `turbo` commands to build
the `gem`, isntead you need to manually build and release Ruby gems. All gems
in the `./gems` directory where created using the standard method described on
[rubygems.org](https://guides.rubygems.org/make-your-own-gem/).

```
cd gems/yrb-actioncable
bundle
rake spec
rake build                                    # y-rb_actioncable 0.1.5 built to pkg/y-rb_actioncable-0.1.5.gem
cd pkg && gem push y-rb_actioncable-0.1.5.gem # release new version on rubygems.org
```

The documentation for a gem is automatically generated and published every time
a PR gets merged into `main`. You can find the documentation here:
https://y-crdt.github.io/yrb-actioncable/

The [sandbox environment](./examples/collaborative-text-editor) and running
Redis specific specs in [./gems/yrb-actioncable](./gems/yrb-actioncable) require
Redis. We use Docker to run the Redis server.

## Contributing

Contributions are welcome. Be nice to people, and follow the following rules.

1. PRs must be rebased, no merge requests allowed (clean history)
2. Commit messages must adhere to this [convention](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)

## License

The gem is available as *open source* under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
