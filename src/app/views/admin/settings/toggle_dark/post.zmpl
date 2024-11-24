<input type="checkbox" {{$.dark}} name="dark"
    hx-post="/admin/settings/toggle_dark"
    hx-target="#toggle-switch"
    hx-swap="innerHTML"
    hx-include="this">
<span class="toggle-slider"></span>
