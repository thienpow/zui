<div class="brand-topbar-conntainer">
    <img src="/icons/logo.svg" class="logo-topbar" alt="zUI Logo">
</div>
<style>
.brand-topbar-container {
    display: flex;
    height: 54px;
    overflow: visible;
}
.logo-topbar {
    visibility: visible;
    position: absolute;
    top: 6px;
    width: 120px;
    height: 52px;
    z-index: 1003;
}
@media (max-width: 768px) {
    .brand-topbar-container {
        display: none;
    }
    .logo-topbar {
        visibility: hidden;
    }
}
</style>
