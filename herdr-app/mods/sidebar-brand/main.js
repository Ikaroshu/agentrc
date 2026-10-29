// The sidebar's brand row from the shipped workspace-chrome mod, without a fill of its own so the
// layout's canvas shows through.
import { View, div, image, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { theme, run, window, shared, setShared } from "herdr";

export default class SidebarBrand extends View {
  button(id, label, action) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.muted).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_click(action).child(label);
  }
  render() {
    const t = theme();
    const collapsed = shared("sidebar.collapsed") === true;
    const toggle = () => {
      setShared("sidebar.collapsed", !collapsed);
      run("layout.resize", { id: "sidebar", px: collapsed ? (shared("sidebar.width") ?? 268) : 44 });
    };
    return h_flex().size_full().pl(collapsed ? 6 : 14).pr(10).gap(4).items_center().text_size(13.5)
      .when(window()?.platform === "macos" && !collapsed, el => el.pl(76))
      .when(!collapsed, el => el.child(h_flex().flex_1().gap(8).items_center().child(image("frame/welcome/herdr.png").size(20).rounded(5)).child(div().font_semibold().text_color(t.foreground).child("Herdr"))))
      .when(!collapsed, el => el.child(this.button("search", svg("mods/workspace-chrome/search.svg").size(15), () => run("mod.open", { name: "picker" }))))
      .child(this.button("sidebar-toggle", svg("mods/workspace-chrome/sidebar.svg").size(15), toggle));
  }
}
