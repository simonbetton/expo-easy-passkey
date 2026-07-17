#include <stdint.h>
#include <stdio.h>

uint32_t ffi_expo_easy_passkey_ffi_uniffi_contract_version(void);

int main(void) {
  uint32_t version = ffi_expo_easy_passkey_ffi_uniffi_contract_version();
  if (version == 0) {
    fprintf(stderr, "FFI smoke failed: uniffi contract version was 0\n");
    return 1;
  }
  printf("uniffi_contract_version=%u\n", version);
  return 0;
}
