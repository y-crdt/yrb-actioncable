import {Controller} from "@hotwired/stimulus";
import {Editor} from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Collaboration from '@tiptap/extension-collaboration';
import CollaborationCursor from '@tiptap/extension-collaboration-cursor';
import {Doc} from "yjs";
import {WebsocketProvider} from "yrb-actioncable";

import consumer from "../channels/consumer";

export default class extends Controller {
  connect() {
    const document = new Doc();
    const provider = new WebsocketProvider(
      document,
      consumer,
      "SyncChannel",
      {path: "issues/1"}
    );

    const editor = new Editor({
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
      content: ''
    });
  }

  getRandomColor() {
    return `#${Math.floor(Math.random()*16777215).toString(16)}`;
  }
}
