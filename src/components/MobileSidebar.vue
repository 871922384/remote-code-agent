<template>
  <div
    class="mobile-drawer"
    :class="{ 'is-open': open }"
    data-mobile-drawer
    @click.self="$emit('close')"
  >
    <aside class="mobile-drawer-panel">
      <slot />
    </aside>
  </div>
</template>

<script setup>
defineProps({
  open: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['close'])
</script>

<style scoped>
.mobile-drawer {
  position: fixed;
  inset: 0;
  display: none;
  background: rgba(1, 8, 16, 0.55);
  backdrop-filter: blur(8px);
  z-index: 30;
}

.mobile-drawer.is-open {
  display: block;
}

.mobile-drawer-panel {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  width: min(88vw, 360px);
  padding: 1rem;
  background: rgba(8, 18, 30, 0.98);
  border-right: 1px solid var(--border);
  overflow: auto;
}
</style>
