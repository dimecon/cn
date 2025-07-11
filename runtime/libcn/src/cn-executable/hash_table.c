/*

MIT License

Copyright (c) 2021 Ben Hoyt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#include <assert.h>
#include <stdint.h>
#include <string.h>

#include <cn-executable/hash_table.h>

#define INITIAL_CAPACITY 16  // must not be zero

hash_table* ht_create(allocator* alloc) {
  // Allocate space for hash table struct.
  hash_table* table = fulm_malloc(sizeof(hash_table), alloc);
  if (table == NULL) {
    return NULL;
  }
  table->length = 0;
  table->capacity = INITIAL_CAPACITY;
  table->alloc = alloc;

  // Allocate (zero'd) space for entry buckets.
  table->entries = fulm_calloc(table->capacity, sizeof(ht_entry), alloc);
  // if (table->entries == NULL) {
  //   fulminate_free(table);  // error, free table before we return!
  //   return NULL;
  // }
  return table;
}

void ht_destroy(hash_table* table) {
  if (table == NULL) {
    return;
  }

  // First free allocated keys.
  for (size_t i = 0; i < table->capacity; i++) {
    fulm_free((void*)table->entries[i].key, table->alloc);
  }

  // Then free entries array and table itself.
  fulm_free(table->entries, table->alloc);
  fulm_free(table, table->alloc);
}

#define FNV_OFFSET 14695981039346656037U
#define FNV_PRIME  1099511628211U

// Return 64-bit FNV-1a hash for key (NUL-terminated). See description:
// https://en.wikipedia.org/wiki/Fowler–Noll–Vo_hash_function
static uint64_t hash_key(int64_t* key) {
  uint64_t hash = FNV_OFFSET;
  hash ^= *key;
  hash *= FNV_PRIME;
  return hash;
}

void* ht_get(hash_table* table, int64_t* key) {
  // AND hash with capacity-1 to ensure it's within entries array.
  uint64_t hash = hash_key(key);
  size_t index = (size_t)(hash & (uint64_t)(table->capacity - 1));

  // Loop till we find an empty entry.
  while (table->entries[index].key != NULL) {
    if (*key == *(table->entries[index].key)) {
      // Found key, return value.
      // printf("Set entry. Key: %d, Value: %c\n", *(signed int *)key, *(char *)value);
      return table->entries[index].value;
    }
    // Key wasn't in this slot, move to next (linear probing).
    index++;
    if (index >= table->capacity) {
      // At end of entries array, wrap around.
      index = 0;
    }
  }
  // printf("Returning NULL from ht_get\n");
  return NULL;
}

int64_t* duplicate_key(int64_t* key, allocator* alloc) {
  int64_t* new_key = fulm_malloc(sizeof(int64_t), alloc);
  *new_key = *key;
  return new_key;
}

// Internal function to set an entry (without expanding table).
static int64_t* ht_set_entry(ht_entry* entries,
    size_t capacity,
    int64_t* key,
    void* value,
    int* plength,
    allocator* alloc) {
  // AND hash with capacity-1 to ensure it's within entries array.
  uint64_t hash = hash_key(key);
  size_t index = (size_t)(hash & (uint64_t)(capacity - 1));

  // Loop till we find an empty entry.
  while (entries[index].key != NULL) {
    if (*key == *(entries[index].key)) {
      // Found key (it already exists), update value.
      entries[index].value = value;
      return entries[index].key;
    }
    // Key wasn't in this slot, move to next (linear probing).
    index++;
    if (index >= capacity) {
      // At end of entries array, wrap around.
      index = 0;
    }
  }

  // Didn't find key, allocate+copy if needed, then insert it.
  if (plength != NULL) {
    key = duplicate_key(key, alloc);
    if (key == NULL) {
      return NULL;
    }
    (*plength)++;
  }
  entries[index].key = key;
  entries[index].value = value;
  return key;
}

// Expand hash table to twice its current size. Return true on success,
// false if out of memory.
static _Bool ht_expand(hash_table* table) {
  // Allocate new entries array.
  size_t new_capacity = table->capacity * 2;
  if (new_capacity < table->capacity) {
    return 0;  // overflow (capacity would be too big)
  }
  ht_entry* new_entries = fulm_calloc(new_capacity, sizeof(ht_entry), table->alloc);
  if (new_entries == NULL) {
    return 0;
  }

  // Iterate entries, move all non-empty ones to new table's entries.
  for (size_t i = 0; i < table->capacity; i++) {
    ht_entry entry = table->entries[i];
    if (entry.key != NULL) {
      ht_set_entry(new_entries, new_capacity, entry.key, entry.value, NULL, table->alloc);
    }
  }

  // Free old entries array and update this table's details.
  fulm_free(table->entries, table->alloc);
  table->entries = new_entries;
  table->capacity = new_capacity;
  return 1;
}

int64_t* ht_set(hash_table* table, int64_t* key, void* value) {
  assert(value != NULL);
  if (value == NULL) {
    return NULL;
  }

  // If length will exceed half of current capacity, expand it.
  if (table->length >= table->capacity / 2) {
    if (!ht_expand(table)) {
      return NULL;
    }
  }

  // Set entry and update length.
  return ht_set_entry(
      table->entries, table->capacity, key, value, &table->length, table->alloc);
}

int ht_size(hash_table* table) {
  return table->length;
}

hash_table_iterator ht_iterator(hash_table* table) {
  hash_table_iterator it;
  it._table = table;
  it._index = 0;
  return it;
}

_Bool ht_next(hash_table_iterator* it) {
  if (it == NULL || it->_table == NULL) {
    return 0;
  }

  // Loop till we've hit end of entries array.
  hash_table* table = it->_table;
  while (it->_index < table->capacity) {
    size_t i = it->_index;
    it->_index++;
    if (table->entries[i].key != NULL) {
      // Found next non-empty item, update iterator key and value.
      ht_entry entry = table->entries[i];
      it->key = entry.key;
      it->value = entry.value;
      return 1;
    }
  }
  return 0;
}
