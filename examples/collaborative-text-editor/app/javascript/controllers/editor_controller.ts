import {Controller} from "@hotwired/stimulus";
import {Editor} from "@tiptap/core";
import {Collaboration} from "@tiptap/extension-collaboration";
import {CollaborationCursor} from "@tiptap/extension-collaboration-cursor";
import {StarterKit} from "@tiptap/starter-kit";
import {ReliableWebsocketProvider} from "@y-rb/actioncable";
import {fromBase64} from "lib0/buffer";
import {applyUpdate, Doc} from "yjs";

import {consumer} from "../channels";

export default class extends Controller<HTMLFormElement> {
  static values = {
    content: String
  };

  declare contentValue: string;
  declare readonly hasCodeValue: boolean;

  connect() {
    const document = new Doc();
    // set initial state
    if (this.contentValue.length > 0) {
      const initialState = fromBase64(this.contentValue);
      applyUpdate(document, initialState);
    }

    const defaultPath = "issues/1";
    const path = new URLSearchParams(window.location.search).get("path") || defaultPath;

    const provider = new ReliableWebsocketProvider(
      document,
      consumer,
      "SyncChannel",
      {path}
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
      "#ff901f",
      "#ff2975",
      "#f222ff",
      "#8c1eff",
    ];

    const selectedIndex = Math.floor(Math.random() * (colors.length - 1));
    return colors[selectedIndex];
  }
}
