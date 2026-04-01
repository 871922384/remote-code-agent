<template>
  <section class="thread-list">
    <header class="list-header">
      <span>会话</span>
    </header>
    <button
      v-for="thread in threads"
      :key="thread.id"
      class="thread-card"
      :class="{ 'is-selected': thread.id === selectedThreadId }"
      :data-thread-id="thread.id"
      type="button"
      @click="$emit('select', thread.id)"
    >
      <strong>{{ thread.title }}</strong>
      <div class="thread-meta">
        <span>{{ thread.engine }}</span>
        <span>{{ formatMessageCount(thread.messageCount) }}</span>
      </div>
    </button>
    <p v-if="threads.length === 0" class="empty-copy">先创建一个会话，再开始聊天。</p>
  </section>
</template>

<script setup>
defineProps({
  threads: {
    type: Array,
    default: () => [],
  },
  selectedThreadId: {
    type: String,
    default: '',
  },
})

defineEmits(['select'])

function formatMessageCount(count) {
  return `${count || 0} 条消息`
}
</script>

<style scoped>
.thread-list {
  display: grid;
  gap: 0.75rem;
}

.list-header {
  color: var(--text-muted);
  font-size: 0.75rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.thread-card {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.015);
  color: var(--text);
  padding: 0.9rem 1rem;
  text-align: left;
  display: grid;
  gap: 0.45rem;
}

.thread-card.is-selected {
  border-color: rgba(143, 227, 176, 0.5);
  background: rgba(143, 227, 176, 0.1);
}

.thread-meta {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  color: var(--text-muted);
  font-size: 0.8rem;
  text-transform: lowercase;
}

.empty-copy {
  margin: 0;
  color: var(--text-muted);
  font-size: 0.86rem;
}
</style>
