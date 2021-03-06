#include <linux/kernel.h>
#include <komodo/smcapi.h>

asmlinkage u64 invoke_smc(u32 callno, u32 arg1, u32 arg2, u32 arg3, u32 arg4);

#ifdef DEBUG_PSR
static inline uint32_t rdcpsr(void)
{
    uint32_t r = 0;
    asm volatile("mrs %0, cpsr" : "=r"(r));
    return r;
}
#endif

u64 _invoke_smc(u32 callno, u32 arg1, u32 arg2, u32 arg3, u32 arg4)
{
    u64 r;
#ifdef DEBUG_PSR
    u32 psr = rdcpsr();
    printk(KERN_DEBUG "pre-invoke  %u: CPSR.F %u .I %u .M %x\n",
           callno, (psr & 0x40) != 0, (psr & 0x80) != 0, psr & 0x1f);
#endif
    r = invoke_smc(callno, arg1, arg2, arg3, arg4);
#ifdef DEBUG_PSR
    psr = rdcpsr();
    printk(KERN_DEBUG "post-invoke %u: CPSR.F %u .I %u .M %x\n",
           callno, (psr & 0x40) != 0, (psr & 0x80) != 0, psr & 0x1f);
#endif
    return r;
}

uint32_t kom_smc_query(void)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_QUERY,0,0,0,0);
    return ret.x.err;
}

uint32_t kom_smc_get_phys_pages(void)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_GETPHYSPAGES,0,0,0,0);
    BUG_ON(ret.x.err != KOM_ERR_SUCCESS);
    return ret.x.val;
}

kom_err_t kom_smc_init_addrspace(kom_secure_pageno_t addrspace_page,
                                 kom_secure_pageno_t l1pt_page)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_INIT_ADDRSPACE, addrspace_page, l1pt_page, 0, 0);
    return ret.x.err;
}

kom_err_t kom_smc_init_dispatcher(kom_secure_pageno_t page,
                                  kom_secure_pageno_t addrspace,
                                  uint32_t entrypoint)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_INIT_DISPATCHER, page, addrspace, entrypoint, 0);
    return ret.x.err;
}

kom_err_t kom_smc_init_l2table(kom_secure_pageno_t page,
                               kom_secure_pageno_t addrspace,
                               uint32_t l1_index)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_INIT_L2PTABLE, page, addrspace, l1_index, 0);
    return ret.x.err;
}

kom_err_t kom_smc_map_secure(kom_secure_pageno_t page,
                             kom_secure_pageno_t addrspace,
                             uint32_t mapping,
                             uint32_t phys_pageno)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_MAP_SECURE, page, addrspace, mapping, phys_pageno);
    return ret.x.err;
}

kom_err_t kom_smc_map_insecure(kom_secure_pageno_t addrspace,
                               uint32_t phys_pageno,
                               uint32_t mapping)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_MAP_INSECURE, addrspace, phys_pageno, mapping, 0);
    return ret.x.err;
}

kom_err_t kom_smc_alloc_spare(kom_secure_pageno_t page,
                              kom_secure_pageno_t addrspace)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_ALLOC_SPARE, page, addrspace, 0, 0);
    return ret.x.err;
}

kom_err_t kom_smc_remove(kom_secure_pageno_t page)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_REMOVE, page, 0, 0, 0);
    return ret.x.err;
}

kom_err_t kom_smc_finalise(kom_secure_pageno_t addrspace)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_FINALISE, addrspace, 0, 0, 0);
    return ret.x.err;
}

kom_err_t kom_smc_stop(kom_secure_pageno_t addrspace)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_STOP, addrspace, 0, 0, 0);
    return ret.x.err;
}

kom_multival_t kom_smc_enter(kom_secure_pageno_t dispatcher, uintptr_t arg1,
                             uintptr_t arg2, uintptr_t arg3)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_ENTER, dispatcher, arg1, arg2, arg3);
    return ret;
}

kom_multival_t kom_smc_resume(kom_secure_pageno_t dispatcher)
{
    kom_multival_t ret;
    ret.raw = _invoke_smc(KOM_SMC_RESUME, dispatcher, 0, 0, 0);
    return ret;
}

kom_multival_t kom_smc_execute(kom_secure_pageno_t dispatcher, uintptr_t arg1,
                               uintptr_t arg2, uintptr_t arg3)
{
    kom_multival_t ret;
    ret = kom_smc_enter(dispatcher, arg1, arg2, arg3);
    while (ret.x.err == KOM_ERR_INTERRUPTED) {
        ret = kom_smc_resume(dispatcher);
    }

    return ret;
}
