<template>
  <form class="composer" @submit.prevent="onSubmit">
    <div class="composer-engine">
      <button
        class="engine-chip"
        :class="{ 'is-active': selectedEngine === 'codex' }"
        data-engine-codex
        type="button"
        @click="$emit('update:engine', 'codex')"
      >
        Codex
      </button>
      <button
        class="engine-chip"
        :class="{ 'is-active': selectedEngine === 'claude' }"
        data-engine-claude
        type="button"
        @click="$emit('update:engine', 'claude')"
      >
        Claude
      </button>
    </div>

    <textarea
      v-model="draft"
      :disabled="disabled || busy"
      placeholder="给当前会话发送消息..."
      rows="3"
    />

    <div class="composer-actions">
      <span class="composer-hint">{{ hintText }}</span>
      <button
        data-action-button
        class="composer-button"
        :class="{ 'is-danger': busy }"
        type="submit"
        :disabled="disabled && !busy"
        @click="busy ? $emit('stop') : null"
      >
        {{ busy ? '停止' : '发送' }}
      </button>
    </div>
  </form>
</template>

<script setup>
import { computed, ref } from 'vue'

const props = defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
  disabledReason: {
    type: String,
    default: '',
  },
  busy: {
    type: Boolean,
    default: false,
  },
  selectedEngine: {
    type: String,
    default: 'codex',
  },
})

const emit = defineEmits(['submit', 'stop', 'update:engine'])
const draft = ref('')
const hintText = computed(() => {
  if (props.busy) return '正在运行，可点击停止。'
  if (props.disabledReason) return props.disabledReason
  if (props.disabled) return '请先创建或选择一个会话。'
  return '回车发送，Shift + 回车换行。'
})

function onSubmit() {
  if (props.busy) {
    emit('stop')
    return
  }

  const prompt = draft.value.trim()
  if (!prompt || props.disabled) return

  emit('submit', {
    prompt,
    engine: props.selectedEngine,
  })
  draft.value = ''
}
</script>

<style scoped>
.composer {
  display: grid;
  gap: 0.85rem;
  border: 1px solid var(--border);
  border-radius: 24px;
  background: var(--panel-strong);
  padding: 1rem;
}

.composer-engine {
  display: inline-flex;
  gap: 0.55rem;
}

.engine-chip {
  border: 1px solid var(--border);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.03);
  color: var(--text-muted);
  padding: 0.5rem 0.9rem;
}

.engine-chip.is-active {
  background: var(--accent-soft);
  border-color: rgba(139, 211, 255, 0.42);
  color: var(--text);
}

textarea {
  width: 100%;
  min-height: 120px;
  border: 1px solid var(--border);
  border-radius: 18px;
  background: rgba(4, 11, 20, 0.74);
  color: var(--text);
  padding: 0.95rem 1rem;
  resize: vertical;
}

.composer-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.composer-hint {
  color: var(--text-muted);
  font-size: 0.84rem;
}

.composer-button {
  border: none;
  border-radius: 18px;
  background: linear-gradient(135deg, var(--accent), var(--accent-strong));
  color: #06101b;
  min-width: 120px;
  padding: 0.9rem 1.1rem;
  font-weight: 700;
}

.composer-button.is-danger {
  background: linear-gradient(135deg, #ff9b9b, #ff6f91);
  color: #fff;
}

.composer-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
