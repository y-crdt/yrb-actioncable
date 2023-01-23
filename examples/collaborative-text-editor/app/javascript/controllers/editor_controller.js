import {Controller} from "@hotwired/stimulus";
import {Editor} from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Collaboration from '@tiptap/extension-collaboration';
import CollaborationCursor from '@tiptap/extension-collaboration-cursor';
import {Doc, applyUpdate} from "yjs";
import {WebsocketProvider} from "@y-rb/actioncable";
import {fromBase64} from "lib0/buffer";

import consumer from "../channels/consumer";

export default class extends Controller {
  static values = {
    content: String
  }

  connect() {
    const document = new Doc();
    // set initial state
    if (typeof this.contentValue == "string" && this.contentValue.length > 0) {
      const initialState = fromBase64(this.contentValue);
      applyUpdate(document, initialState);
    }

    const provider = new WebsocketProvider(
      document,
      consumer,
      "SyncChannel",
      {path: "issues/1"}
    );

    new Editor({
      element: this.element,
      extensions: [
        StarterKit.configure({
          history: false
        }),
        Collaboration.configure({
          document
        }),
        CollaborationCursor.configure({
          provider,
          user: {
            name: "Hannes Moser",
            color: this.getRandomColor()
          }
        })
      ],
    });
  }

  getRandomColor() {
    const colors = [
      `#ff901f`,
      `#ff2975`,
      `#f222ff`,
      `#8c1eff`,
    ];

    const selectedIndex = Math.floor(Math.random() * (colors.length - 1));
    return colors[selectedIndex];
  }
}
