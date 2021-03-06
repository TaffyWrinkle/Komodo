typedef union {
    struct {
        uint32_t type:2; // 0x0
        uint32_t ignored:30;
    } invalid;
    struct {
        uint32_t type:2; // 0x1
        uint32_t pxn:1;
        uint32_t ns:1;
        uint32_t sbz:1;
        uint32_t domain:4;
        uint32_t impl:1;
        uint32_t ptbase:22;
    } pagetable;
    struct {
        uint32_t pxn:1;
        uint32_t type:1; // 0x1
        uint32_t b:1;
        uint32_t c:1;
        uint32_t xn:1;
        uint32_t domain:4;
        uint32_t impl:1;
        uint32_t ap0:1;
        uint32_t ap1:1;
        uint32_t tex:3;
        uint32_t ap2:1;
        uint32_t s:1;
        uint32_t ng:1;
        uint32_t mbz:1; // 0
        uint32_t ns:1;
        uint32_t secbase:12;
    } section;
    uint32_t raw;
} armpte_short_l1;

typedef union {
    struct {
        uint32_t type:2; // 0x0
        uint32_t ignored:30;
    } invalid;
    struct {
        uint32_t type:2; // 0x1;
        uint32_t b:1;
        uint32_t c:1;
        uint32_t ap0:1;
        uint32_t ap1:1;
        uint32_t sbz:3;
        uint32_t ap2:1;
        uint32_t s:1;
        uint32_t ng:1;
        uint32_t tex:3;
        uint32_t xn:1;
        uint32_t base:16;
    } largepage;
    struct {
        uint32_t xn:1;
        uint32_t type:1; // 0x1;
        uint32_t b:1;
        uint32_t c:1;
        uint32_t ap0:1;
        uint32_t ap1:1;
        uint32_t tex:3;
        uint32_t ap2:1;
        uint32_t s:1;
        uint32_t ng:1;
        uint32_t base:20;
    } smallpage;
    uint32_t raw;
} armpte_short_l2;


// the level 1 table occupies 16kB, or 4096 entries
#define ARM_L1_PTABLE_ENTRIES 0x1000
#define ARM_L1_PTABLE_BYTES (ARM_L1_PTABLE_ENTRIES * sizeof(armpte_short_l1))

// section mappings are 1MB each
#define ARM_L1_SECTION_SIZE 0x100000
#define ARM_L1_SECTION_BITS 20
