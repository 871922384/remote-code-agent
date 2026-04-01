<template>
  <section class="message-panel">
    <header class="message-header">
      <div>
        <p class="eyebrow">会话</p>
        <h2>对话</h2>
      </div>
      <span class="status-pill">{{ statusLabel }}</span>
    </header>

    <div class="message-scroll">
      <article
        v-for="message in messages"
        :key="message.id"
        class="message-card"
        :class="`is-${message.role}`"
      >
        <div class="message-card-header">
          <strong>{{ message.role === 'user' ? '你' : message.engine || 'assistant' }}</strong>
          <span>{{ message.role }}</span>
        </div>
        <p>{{ message.text }}</p>
      </article>

      <p v-if="messages.length === 0" class="empty-copy">消息会显示在这里。</p>
    </div>
  </section>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  messages: {
    type: Array,
    default: () => [],
  },
  threadStatus: {
    type: String,
    default: 'idle',
  },
})

const statusLabel = computed(() => {
  if (props.threadStatus === 'running') return '运行中'
  if (props.threadStatus === 'stopped') return '已停止'
  if (props.threadStatus === 'error') return '出错'
  return '就绪'
})
</script>

<style scoped>
.message-panel {
  min-height: 0;
  display: grid;
  grid-template-rows: auto 1fr;
  border: 1px solid var(--border);
  border-radius: 28px;
  background: var(--panel);
  backdrop-filter: blur(20px);
}

.message-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.25rem 1.4rem 1rem;
  border-bottom: 1px solid var(--border);
}

.eyebrow {
  margin: 0 0 0.25rem;
  color: var(--text-muted);
  font-size: 0.72rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.message-header h2 {
  margin: 0;
  font-size: 1.2rem;
  font-weight: 600;
}

.status-pill {
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.06);
  padding: 0.45rem 0.8rem;
  color: var(--accent);
  font-size: 0.82rem;
}

.message-scroll {
  min-height: 0;
  overflow: auto;
  display: grid;
  gap: 0.95rem;
  padding: 1.1rem 1.25rem 1.4rem;
}

.message-card {
  border-radius: 22px;
  padding: 1rem 1.1rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid transparent;
}

.message-card.is-user {
  border-color: rgba(139, 211, 255, 0.25);
}

.message-card.is-assistant {
  border-color: rgba(143, 227, 176, 0.22);
}

.message-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
  text-transform: capitalize;
}

.message-card p {
  margin: 0;
  white-space: pre-wrap;
  line-height: 1.65;
}

.empty-copy {
  margin: auto 0;
  color: var(--text-muted);
}
</style>
