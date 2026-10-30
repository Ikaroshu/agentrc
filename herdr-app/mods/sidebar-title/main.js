// The sidebar's title on the window's top row: lined up with the space avatars below in full
// screen, and with the spaces card's right edge when the macOS window buttons take the left.
import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { theme, window } from "herdr";

export default class SidebarTitle extends View {
  render() {
    const t = theme(), w = window(), lights = w?.platform === "macos" && !w.fullscreen;
    return h_flex().size_full().px(16).items_center().when(lights, el => el.justify_end()).text_size(12.8)
      .child(div().font_medium().text_color(t.foreground).child("Spaces"));
  }
}
