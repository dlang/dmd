/*
* D header file for perf_event_open system call.
*
* Converted/Bodged from linux userspace header
*
* Copyright: Max Haughton 2020
* License: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
* Authors: Max Haughton
 */
module core.sys.linux.perf_event;
version (linux):
extern (C):
@nogc:
nothrow:
@system:

import core.sys.posix.sys.ioctl;
import core.sys.posix.unistd;

version (X86_64)
{
    enum __NR_perf_event_open = 298;
}
else version (X86)
{
    enum __NR_perf_event_open = 336;
}
else version (ARM)
{
    enum __NR_perf_event_open = 364;
}
else version (ARM64)
{
    enum __NR_perf_event_open = 241;
}
extern (C) extern long syscall(long __sysno, ...);
static long perf_event_open(perf_event_attr* hw_event, pid_t pid, int cpu, int group_fd, ulong flags)
{
    return syscall(__NR_perf_event_open, hw_event, pid, cpu, group_fd, flags);
}

enum perf_type_id
{
    PERF_TYPE_HARDWARE = 0,
    PERF_TYPE_SOFTWARE = 1,
    PERF_TYPE_TRACEPOINT = 2,
    PERF_TYPE_HW_CACHE = 3,
    PERF_TYPE_RAW = 4,
    PERF_TYPE_BREAKPOINT = 5,

    PERF_TYPE_MAX = 6
}

enum perf_hw_id
{

    PERF_COUNT_HW_CPU_CYCLES = 0,
    PERF_COUNT_HW_INSTRUCTIONS = 1,
    PERF_COUNT_HW_CACHE_REFERENCES = 2,
    PERF_COUNT_HW_CACHE_MISSES = 3,
    PERF_COUNT_HW_BRANCH_INSTRUCTIONS = 4,
    PERF_COUNT_HW_BRANCH_MISSES = 5,
    PERF_COUNT_HW_BUS_CYCLES = 6,
    PERF_COUNT_HW_STALLED_CYCLES_FRONTEND = 7,
    PERF_COUNT_HW_STALLED_CYCLES_BACKEND = 8,
    PERF_COUNT_HW_REF_CPU_CYCLES = 9,

    PERF_COUNT_HW_MAX = 10
}

enum perf_hw_cache_id
{
    PERF_COUNT_HW_CACHE_L1D = 0,
    PERF_COUNT_HW_CACHE_L1I = 1,
    PERF_COUNT_HW_CACHE_LL = 2,
    PERF_COUNT_HW_CACHE_DTLB = 3,
    PERF_COUNT_HW_CACHE_ITLB = 4,
    PERF_COUNT_HW_CACHE_BPU = 5,
    PERF_COUNT_HW_CACHE_NODE = 6,

    PERF_COUNT_HW_CACHE_MAX = 7
}

enum perf_hw_cache_op_id
{
    PERF_COUNT_HW_CACHE_OP_READ = 0,
    PERF_COUNT_HW_CACHE_OP_WRITE = 1,
    PERF_COUNT_HW_CACHE_OP_PREFETCH = 2,

    PERF_COUNT_HW_CACHE_OP_MAX = 3
}

enum perf_hw_cache_op_result_id
{
    PERF_COUNT_HW_CACHE_RESULT_ACCESS = 0,
    PERF_COUNT_HW_CACHE_RESULT_MISS = 1,

    PERF_COUNT_HW_CACHE_RESULT_MAX = 2
}

enum perf_sw_ids
{
    PERF_COUNT_SW_CPU_CLOCK = 0,
    PERF_COUNT_SW_TASK_CLOCK = 1,
    PERF_COUNT_SW_PAGE_FAULTS = 2,
    PERF_COUNT_SW_CONTEXT_SWITCHES = 3,
    PERF_COUNT_SW_CPU_MIGRATIONS = 4,
    PERF_COUNT_SW_PAGE_FAULTS_MIN = 5,
    PERF_COUNT_SW_PAGE_FAULTS_MAJ = 6,
    PERF_COUNT_SW_ALIGNMENT_FAULTS = 7,
    PERF_COUNT_SW_EMULATION_FAULTS = 8,
    PERF_COUNT_SW_DUMMY = 9,
    PERF_COUNT_SW_BPF_OUTPUT = 10,

    PERF_COUNT_SW_MAX = 11
}

enum perf_event_sample_format
{
    PERF_SAMPLE_IP = 1U << 0,
    PERF_SAMPLE_TID = 1U << 1,
    PERF_SAMPLE_TIME = 1U << 2,
    PERF_SAMPLE_ADDR = 1U << 3,
    PERF_SAMPLE_READ = 1U << 4,
    PERF_SAMPLE_CALLCHAIN = 1U << 5,
    PERF_SAMPLE_ID = 1U << 6,
    PERF_SAMPLE_CPU = 1U << 7,
    PERF_SAMPLE_PERIOD = 1U << 8,
    PERF_SAMPLE_STREAM_ID = 1U << 9,
    PERF_SAMPLE_RAW = 1U << 10,
    PERF_SAMPLE_BRANCH_STACK = 1U << 11,
    PERF_SAMPLE_REGS_USER = 1U << 12,
    PERF_SAMPLE_STACK_USER = 1U << 13,
    PERF_SAMPLE_WEIGHT = 1U << 14,
    PERF_SAMPLE_DATA_SRC = 1U << 15,
    PERF_SAMPLE_IDENTIFIER = 1U << 16,
    PERF_SAMPLE_TRANSACTION = 1U << 17,
    PERF_SAMPLE_REGS_INTR = 1U << 18,
    PERF_SAMPLE_PHYS_ADDR = 1U << 19,

    PERF_SAMPLE_MAX = 1U << 20
}

enum perf_branch_sample_type_shift
{
    PERF_SAMPLE_BRANCH_USER_SHIFT = 0,
    PERF_SAMPLE_BRANCH_KERNEL_SHIFT = 1,
    PERF_SAMPLE_BRANCH_HV_SHIFT = 2,

    PERF_SAMPLE_BRANCH_ANY_SHIFT = 3,
    PERF_SAMPLE_BRANCH_ANY_CALL_SHIFT = 4,
    PERF_SAMPLE_BRANCH_ANY_RETURN_SHIFT = 5,
    PERF_SAMPLE_BRANCH_IND_CALL_SHIFT = 6,
    PERF_SAMPLE_BRANCH_ABORT_TX_SHIFT = 7,
    PERF_SAMPLE_BRANCH_IN_TX_SHIFT = 8,
    PERF_SAMPLE_BRANCH_NO_TX_SHIFT = 9,
    PERF_SAMPLE_BRANCH_COND_SHIFT = 10,

    PERF_SAMPLE_BRANCH_CALL_STACK_SHIFT = 11,
    PERF_SAMPLE_BRANCH_IND_JUMP_SHIFT = 12,
    PERF_SAMPLE_BRANCH_CALL_SHIFT = 13,

    PERF_SAMPLE_BRANCH_NO_FLAGS_SHIFT = 14,
    PERF_SAMPLE_BRANCH_NO_CYCLES_SHIFT = 15,

    PERF_SAMPLE_BRANCH_TYPE_SAVE_SHIFT = 16,

    PERF_SAMPLE_BRANCH_MAX_SHIFT = 17
}

enum perf_branch_sample_type
{
    PERF_SAMPLE_BRANCH_USER = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_USER_SHIFT,
    PERF_SAMPLE_BRANCH_KERNEL
        = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_KERNEL_SHIFT,
        PERF_SAMPLE_BRANCH_HV = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_HV_SHIFT,

        PERF_SAMPLE_BRANCH_ANY = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_ANY_SHIFT,
        PERF_SAMPLE_BRANCH_ANY_CALL = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_ANY_CALL_SHIFT,
        PERF_SAMPLE_BRANCH_ANY_RETURN = 1U << perf_branch_sample_type_shift
        .PERF_SAMPLE_BRANCH_ANY_RETURN_SHIFT, PERF_SAMPLE_BRANCH_IND_CALL
        = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_IND_CALL_SHIFT,
        PERF_SAMPLE_BRANCH_ABORT_TX = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_ABORT_TX_SHIFT,
        PERF_SAMPLE_BRANCH_IN_TX = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_IN_TX_SHIFT,
        PERF_SAMPLE_BRANCH_NO_TX = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_NO_TX_SHIFT,
        PERF_SAMPLE_BRANCH_COND = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_COND_SHIFT,

        PERF_SAMPLE_BRANCH_CALL_STACK = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_CALL_STACK_SHIFT,
        PERF_SAMPLE_BRANCH_IND_JUMP = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_IND_JUMP_SHIFT,
        PERF_SAMPLE_BRANCH_CALL = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_CALL_SHIFT,

        PERF_SAMPLE_BRANCH_NO_FLAGS = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_NO_FLAGS_SHIFT,
        PERF_SAMPLE_BRANCH_NO_CYCLES = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_NO_CYCLES_SHIFT,

        PERF_SAMPLE_BRANCH_TYPE_SAVE = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_TYPE_SAVE_SHIFT,

        PERF_SAMPLE_BRANCH_MAX = 1U << perf_branch_sample_type_shift.PERF_SAMPLE_BRANCH_MAX_SHIFT
}

enum
{
    PERF_BR_UNKNOWN = 0,
    PERF_BR_COND = 1,
    PERF_BR_UNCOND = 2,
    PERF_BR_IND = 3,
    PERF_BR_CALL = 4,
    PERF_BR_IND_CALL = 5,
    PERF_BR_RET = 6,
    PERF_BR_SYSCALL = 7,
    PERF_BR_SYSRET = 8,
    PERF_BR_COND_CALL = 9,
    PERF_BR_COND_RET = 10,
    PERF_BR_MAX = 11
}

enum PERF_SAMPLE_BRANCH_PLM_ALL = perf_branch_sample_type.PERF_SAMPLE_BRANCH_USER
    | perf_branch_sample_type.PERF_SAMPLE_BRANCH_KERNEL
    | perf_branch_sample_type.PERF_SAMPLE_BRANCH_HV;

enum perf_sample_regs_abi
{
    PERF_SAMPLE_REGS_ABI_NONE = 0,
    PERF_SAMPLE_REGS_ABI_32 = 1,
    PERF_SAMPLE_REGS_ABI_64 = 2
}

enum
{
    PERF_TXN_ELISION = 1 << 0,
    PERF_TXN_TRANSACTION = 1 << 1,
    PERF_TXN_SYNC = 1 << 2,
    PERF_TXN_ASYNC = 1 << 3,
    PERF_TXN_RETRY = 1 << 4,
    PERF_TXN_CONFLICT = 1 << 5,
    PERF_TXN_CAPACITY_WRITE = 1 << 6,
    PERF_TXN_CAPACITY_READ = 1 << 7,

    PERF_TXN_MAX = 1 << 8,

    PERF_TXN_ABORT_SHIFT = 32
}
enum perf_event_read_format
{
    PERF_FORMAT_TOTAL_TIME_ENABLED = 1U << 0,
    PERF_FORMAT_TOTAL_TIME_RUNNING = 1U << 1,
    PERF_FORMAT_ID = 1U << 2,
    PERF_FORMAT_GROUP = 1U << 3,

    PERF_FORMAT_MAX = 1U << 4
}

enum PERF_ATTR_SIZE_VER0 = 64;
enum PERF_ATTR_SIZE_VER1 = 72;
enum PERF_ATTR_SIZE_VER2 = 80;
enum PERF_ATTR_SIZE_VER3 = 96;

enum PERF_ATTR_SIZE_VER4 = 104;
enum PERF_ATTR_SIZE_VER5 = 112;

struct perf_event_attr
{

    uint type;

    uint size;

    ulong config;

    union
    {
        ulong sample_period;
        ulong sample_freq;
    }

    ulong sample_type;
    ulong read_format;
    private ulong _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1;
    @property ulong disabled() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 1U) >> 0U;
        return cast(ulong) result;
    }

    @property void disabled(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= disabled_min, "Value is smaller than the minimum value of bitfield 'disabled'");
        assert(v <= disabled_max, "Value is greater than the maximum value of bitfield 'disabled'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 1U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 0U) & 1U));
    }

    enum ulong disabled_min = cast(ulong) 0U;
    enum ulong disabled_max = cast(ulong) 1U;
    @property ulong inherit() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 2U) >> 1U;
        return cast(ulong) result;
    }

    @property void inherit(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= inherit_min, "Value is smaller than the minimum value of bitfield 'inherit'");
        assert(v <= inherit_max, "Value is greater than the maximum value of bitfield 'inherit'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 2U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 1U) & 2U));
    }

    enum ulong inherit_min = cast(ulong) 0U;
    enum ulong inherit_max = cast(ulong) 1U;
    @property ulong pinned() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 4U) >> 2U;
        return cast(ulong) result;
    }

    @property void pinned(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= pinned_min, "Value is smaller than the minimum value of bitfield 'pinned'");
        assert(v <= pinned_max, "Value is greater than the maximum value of bitfield 'pinned'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 4U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 2U) & 4U));
    }

    enum ulong pinned_min = cast(ulong) 0U;
    enum ulong pinned_max = cast(ulong) 1U;
    @property ulong exclusive() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 8U) >> 3U;
        return cast(ulong) result;
    }

    @property void exclusive(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclusive_min,
                "Value is smaller than the minimum value of bitfield 'exclusive'");
        assert(v <= exclusive_max,
                "Value is greater than the maximum value of bitfield 'exclusive'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 8U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 3U) & 8U));
    }

    enum ulong exclusive_min = cast(ulong) 0U;
    enum ulong exclusive_max = cast(ulong) 1U;
    @property ulong exclude_user() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 16U) >> 4U;
        return cast(ulong) result;
    }

    @property void exclude_user(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_user_min,
                "Value is smaller than the minimum value of bitfield 'exclude_user'");
        assert(v <= exclude_user_max,
                "Value is greater than the maximum value of bitfield 'exclude_user'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 16U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 4U) & 16U));
    }

    enum ulong exclude_user_min = cast(ulong) 0U;
    enum ulong exclude_user_max = cast(ulong) 1U;
    @property ulong exclude_kernel() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 32U) >> 5U;
        return cast(ulong) result;
    }

    @property void exclude_kernel(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_kernel_min,
                "Value is smaller than the minimum value of bitfield 'exclude_kernel'");
        assert(v <= exclude_kernel_max,
                "Value is greater than the maximum value of bitfield 'exclude_kernel'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 32U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 5U) & 32U));
    }

    enum ulong exclude_kernel_min = cast(ulong) 0U;
    enum ulong exclude_kernel_max = cast(ulong) 1U;
    @property ulong exclude_hv() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 64U) >> 6U;
        return cast(ulong) result;
    }

    @property void exclude_hv(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_hv_min,
                "Value is smaller than the minimum value of bitfield 'exclude_hv'");
        assert(v <= exclude_hv_max,
                "Value is greater than the maximum value of bitfield 'exclude_hv'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 64U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 6U) & 64U));
    }

    enum ulong exclude_hv_min = cast(ulong) 0U;
    enum ulong exclude_hv_max = cast(ulong) 1U;
    @property ulong exclude_idle() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 128U) >> 7U;
        return cast(ulong) result;
    }

    @property void exclude_idle(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_idle_min,
                "Value is smaller than the minimum value of bitfield 'exclude_idle'");
        assert(v <= exclude_idle_max,
                "Value is greater than the maximum value of bitfield 'exclude_idle'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 128U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 7U) & 128U));
    }

    enum ulong exclude_idle_min = cast(ulong) 0U;
    enum ulong exclude_idle_max = cast(ulong) 1U;
    @property ulong mmap() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 256U) >> 8U;
        return cast(ulong) result;
    }

    @property void mmap(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= mmap_min, "Value is smaller than the minimum value of bitfield 'mmap'");
        assert(v <= mmap_max, "Value is greater than the maximum value of bitfield 'mmap'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 256U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 8U) & 256U));
    }

    enum ulong mmap_min = cast(ulong) 0U;
    enum ulong mmap_max = cast(ulong) 1U;
    @property ulong comm() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 512U) >> 9U;
        return cast(ulong) result;
    }

    @property void comm(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= comm_min, "Value is smaller than the minimum value of bitfield 'comm'");
        assert(v <= comm_max, "Value is greater than the maximum value of bitfield 'comm'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 512U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 9U) & 512U));
    }

    enum ulong comm_min = cast(ulong) 0U;
    enum ulong comm_max = cast(ulong) 1U;
    @property ulong freq() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 1024U) >> 10U;
        return cast(ulong) result;
    }

    @property void freq(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= freq_min, "Value is smaller than the minimum value of bitfield 'freq'");
        assert(v <= freq_max, "Value is greater than the maximum value of bitfield 'freq'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 1024U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 10U) & 1024U));
    }

    enum ulong freq_min = cast(ulong) 0U;
    enum ulong freq_max = cast(ulong) 1U;
    @property ulong inherit_stat() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 2048U) >> 11U;
        return cast(ulong) result;
    }

    @property void inherit_stat(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= inherit_stat_min,
                "Value is smaller than the minimum value of bitfield 'inherit_stat'");
        assert(v <= inherit_stat_max,
                "Value is greater than the maximum value of bitfield 'inherit_stat'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 2048U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 11U) & 2048U));
    }

    enum ulong inherit_stat_min = cast(ulong) 0U;
    enum ulong inherit_stat_max = cast(ulong) 1U;
    @property ulong enable_on_exec() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 4096U) >> 12U;
        return cast(ulong) result;
    }

    @property void enable_on_exec(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= enable_on_exec_min,
                "Value is smaller than the minimum value of bitfield 'enable_on_exec'");
        assert(v <= enable_on_exec_max,
                "Value is greater than the maximum value of bitfield 'enable_on_exec'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 4096U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 12U) & 4096U));
    }

    enum ulong enable_on_exec_min = cast(ulong) 0U;
    enum ulong enable_on_exec_max = cast(ulong) 1U;
    @property ulong task() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 8192U) >> 13U;
        return cast(ulong) result;
    }

    @property void task(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= task_min, "Value is smaller than the minimum value of bitfield 'task'");
        assert(v <= task_max, "Value is greater than the maximum value of bitfield 'task'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 8192U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 13U) & 8192U));
    }

    enum ulong task_min = cast(ulong) 0U;
    enum ulong task_max = cast(ulong) 1U;
    @property ulong watermark() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 16384U) >> 14U;
        return cast(ulong) result;
    }

    @property void watermark(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= watermark_min,
                "Value is smaller than the minimum value of bitfield 'watermark'");
        assert(v <= watermark_max,
                "Value is greater than the maximum value of bitfield 'watermark'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 16384U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 14U) & 16384U));
    }

    enum ulong watermark_min = cast(ulong) 0U;
    enum ulong watermark_max = cast(ulong) 1U;
    @property ulong precise_ip() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 98304U) >> 15U;
        return cast(ulong) result;
    }

    @property void precise_ip(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= precise_ip_min,
                "Value is smaller than the minimum value of bitfield 'precise_ip'");
        assert(v <= precise_ip_max,
                "Value is greater than the maximum value of bitfield 'precise_ip'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 98304U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 15U) & 98304U));
    }

    enum ulong precise_ip_min = cast(ulong) 0U;
    enum ulong precise_ip_max = cast(ulong) 3U;
    @property ulong mmap_data() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 131072U) >> 17U;
        return cast(ulong) result;
    }

    @property void mmap_data(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= mmap_data_min,
                "Value is smaller than the minimum value of bitfield 'mmap_data'");
        assert(v <= mmap_data_max,
                "Value is greater than the maximum value of bitfield 'mmap_data'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 131072U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 17U) & 131072U));
    }

    enum ulong mmap_data_min = cast(ulong) 0U;
    enum ulong mmap_data_max = cast(ulong) 1U;
    @property ulong sample_id_all() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 262144U) >> 18U;
        return cast(ulong) result;
    }

    @property void sample_id_all(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= sample_id_all_min,
                "Value is smaller than the minimum value of bitfield 'sample_id_all'");
        assert(v <= sample_id_all_max,
                "Value is greater than the maximum value of bitfield 'sample_id_all'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 262144U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 18U) & 262144U));
    }

    enum ulong sample_id_all_min = cast(ulong) 0U;
    enum ulong sample_id_all_max = cast(ulong) 1U;
    @property ulong exclude_host() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 524288U) >> 19U;
        return cast(ulong) result;
    }

    @property void exclude_host(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_host_min,
                "Value is smaller than the minimum value of bitfield 'exclude_host'");
        assert(v <= exclude_host_max,
                "Value is greater than the maximum value of bitfield 'exclude_host'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 524288U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 19U) & 524288U));
    }

    enum ulong exclude_host_min = cast(ulong) 0U;
    enum ulong exclude_host_max = cast(ulong) 1U;
    @property ulong exclude_guest() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 1048576U) >> 20U;
        return cast(ulong) result;
    }

    @property void exclude_guest(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_guest_min,
                "Value is smaller than the minimum value of bitfield 'exclude_guest'");
        assert(v <= exclude_guest_max,
                "Value is greater than the maximum value of bitfield 'exclude_guest'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 1048576U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 20U) & 1048576U));
    }

    enum ulong exclude_guest_min = cast(ulong) 0U;
    enum ulong exclude_guest_max = cast(ulong) 1U;
    @property ulong exclude_callchain_kernel() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 2097152U) >> 21U;
        return cast(ulong) result;
    }

    @property void exclude_callchain_kernel(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_callchain_kernel_min,
                "Value is smaller than the minimum value of bitfield 'exclude_callchain_kernel'");
        assert(v <= exclude_callchain_kernel_max,
                "Value is greater than the maximum value of bitfield 'exclude_callchain_kernel'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 2097152U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 21U) & 2097152U));
    }

    enum ulong exclude_callchain_kernel_min = cast(ulong) 0U;
    enum ulong exclude_callchain_kernel_max = cast(ulong) 1U;
    @property ulong exclude_callchain_user() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 4194304U) >> 22U;
        return cast(ulong) result;
    }

    @property void exclude_callchain_user(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= exclude_callchain_user_min,
                "Value is smaller than the minimum value of bitfield 'exclude_callchain_user'");
        assert(v <= exclude_callchain_user_max,
                "Value is greater than the maximum value of bitfield 'exclude_callchain_user'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 4194304U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 22U) & 4194304U));
    }

    enum ulong exclude_callchain_user_min = cast(ulong) 0U;
    enum ulong exclude_callchain_user_max = cast(ulong) 1U;
    @property ulong mmap2() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 8388608U) >> 23U;
        return cast(ulong) result;
    }

    @property void mmap2(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= mmap2_min, "Value is smaller than the minimum value of bitfield 'mmap2'");
        assert(v <= mmap2_max, "Value is greater than the maximum value of bitfield 'mmap2'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 8388608U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 23U) & 8388608U));
    }

    enum ulong mmap2_min = cast(ulong) 0U;
    enum ulong mmap2_max = cast(ulong) 1U;
    @property ulong comm_exec() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 16777216U) >> 24U;
        return cast(ulong) result;
    }

    @property void comm_exec(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= comm_exec_min,
                "Value is smaller than the minimum value of bitfield 'comm_exec'");
        assert(v <= comm_exec_max,
                "Value is greater than the maximum value of bitfield 'comm_exec'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 16777216U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 24U) & 16777216U));
    }

    enum ulong comm_exec_min = cast(ulong) 0U;
    enum ulong comm_exec_max = cast(ulong) 1U;
    @property ulong use_clockid() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 33554432U) >> 25U;
        return cast(ulong) result;
    }

    @property void use_clockid(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= use_clockid_min,
                "Value is smaller than the minimum value of bitfield 'use_clockid'");
        assert(v <= use_clockid_max,
                "Value is greater than the maximum value of bitfield 'use_clockid'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 33554432U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 25U) & 33554432U));
    }

    enum ulong use_clockid_min = cast(ulong) 0U;
    enum ulong use_clockid_max = cast(ulong) 1U;
    @property ulong context_switch() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 67108864U) >> 26U;
        return cast(ulong) result;
    }

    @property void context_switch(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= context_switch_min,
                "Value is smaller than the minimum value of bitfield 'context_switch'");
        assert(v <= context_switch_max,
                "Value is greater than the maximum value of bitfield 'context_switch'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 67108864U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 26U) & 67108864U));
    }

    enum ulong context_switch_min = cast(ulong) 0U;
    enum ulong context_switch_max = cast(ulong) 1U;
    @property ulong write_backward() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 134217728U) >> 27U;
        return cast(ulong) result;
    }

    @property void write_backward(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= write_backward_min,
                "Value is smaller than the minimum value of bitfield 'write_backward'");
        assert(v <= write_backward_max,
                "Value is greater than the maximum value of bitfield 'write_backward'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 134217728U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 27U) & 134217728U));
    }

    enum ulong write_backward_min = cast(ulong) 0U;
    enum ulong write_backward_max = cast(ulong) 1U;
    @property ulong namespaces() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 268435456U) >> 28U;
        return cast(ulong) result;
    }

    @property void namespaces(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= namespaces_min,
                "Value is smaller than the minimum value of bitfield 'namespaces'");
        assert(v <= namespaces_max,
                "Value is greater than the maximum value of bitfield 'namespaces'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 268435456U)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 28U) & 268435456U));
    }

    enum ulong namespaces_min = cast(ulong) 0U;
    enum ulong namespaces_max = cast(ulong) 1U;
    @property ulong __reserved_1() @safe pure nothrow @nogc const
    {
        auto result = (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & 18446744073172680704UL) >> 29U;
        return cast(ulong) result;
    }

    @property void __reserved_1(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= __reserved_1_min,
                "Value is smaller than the minimum value of bitfield '__reserved_1'");
        assert(v <= __reserved_1_max,
                "Value is greater than the maximum value of bitfield '__reserved_1'");
        _disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 = cast(
                typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1))(
                (_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1 & (
                -1 - cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) 18446744073172680704UL)) | (
                (cast(typeof(_disabled_inherit_pinned_exclusive_exclude_user_exclude_kernel_exclude_hv_exclude_idle_mmap_comm_freq_inherit_stat_enable_on_exec_task_watermark_precise_ip_mmap_data_sample_id_all_exclude_host_exclude_guest_exclude_callchain_kernel_exclude_callchain_user_mmap2_comm_exec_use_clockid_context_switch_write_backward_namespaces___reserved_1)) v << 29U) & 18446744073172680704UL));
    }

    enum ulong __reserved_1_min = cast(ulong) 0U;
    enum ulong __reserved_1_max = cast(ulong) 34359738367UL;
    union
    {
        uint wakeup_events;
        uint wakeup_watermark;
    }

    uint bp_type;

    union
    {
        ulong bp_addr;
        ulong config1;
    }

    union
    {
        ulong bp_len;
        ulong config2;
    }

    ulong branch_sample_type;

    ulong sample_regs_user;

    uint sample_stack_user;

    int clockid;
    ulong sample_regs_intr;

    uint aux_watermark;
    ushort sample_max_stack;
    ushort __reserved_2;
}

extern (D) auto perf_flags(T)(auto ref T attr)
{
    return *(&attr.read_format + 1);
}

enum PERF_EVENT_IOC_ENABLE = _IO('$', 0);
enum PERF_EVENT_IOC_DISABLE = _IO('$', 1);
enum PERF_EVENT_IOC_REFRESH = _IO('$', 2);
enum PERF_EVENT_IOC_RESET = _IO('$', 3);
enum PERF_EVENT_IOC_PERIOD = _IOW!ulong('$', 4);
enum PERF_EVENT_IOC_SET_OUTPUT = _IO('$', 5);
enum PERF_EVENT_IOC_SET_FILTER = _IOW!(char*)('$', 6);
enum PERF_EVENT_IOC_ID = _IOR!(ulong*)('$', 7);
enum PERF_EVENT_IOC_SET_BPF = _IOW!uint('$', 8);
enum PERF_EVENT_IOC_PAUSE_OUTPUT = _IOW!uint('$', 9);

enum perf_event_ioc_flags
{
    PERF_IOC_FLAG_GROUP = 1U << 0
}

struct perf_event_mmap_page
{
    uint version_;
    uint compat_version;
    uint lock;
    uint index;
    long offset;
    ulong time_enabled;
    ulong time_running;
    union
    {
        ulong capabilities;

        struct
        {

            private ulong _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res;
            @property ulong cap_bit0() @safe pure nothrow @nogc const
            {
                auto result = (
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & 1U) >> 0U;
                return cast(ulong) result;
            }

            @property void cap_bit0(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= cap_bit0_min,
                        "Value is smaller than the minimum value of bitfield 'cap_bit0'");
                assert(v <= cap_bit0_max,
                        "Value is greater than the maximum value of bitfield 'cap_bit0'");
                _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res = cast(
                        typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res))((_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & (
                        -1 - cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) 1U)) | (
                        (cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) v << 0U) & 1U));
            }

            enum ulong cap_bit0_min = cast(ulong) 0U;
            enum ulong cap_bit0_max = cast(ulong) 1U;
            @property ulong cap_bit0_is_deprecated() @safe pure nothrow @nogc const
            {
                auto result = (
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & 2U) >> 1U;
                return cast(ulong) result;
            }

            @property void cap_bit0_is_deprecated(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= cap_bit0_is_deprecated_min,
                        "Value is smaller than the minimum value of bitfield 'cap_bit0_is_deprecated'");
                assert(v <= cap_bit0_is_deprecated_max,
                        "Value is greater than the maximum value of bitfield 'cap_bit0_is_deprecated'");
                _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res = cast(
                        typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res))((_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & (
                        -1 - cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) 2U)) | (
                        (cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) v << 1U) & 2U));
            }

            enum ulong cap_bit0_is_deprecated_min = cast(ulong) 0U;
            enum ulong cap_bit0_is_deprecated_max = cast(ulong) 1U;
            @property ulong cap_user_rdpmc() @safe pure nothrow @nogc const
            {
                auto result = (
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & 4U) >> 2U;
                return cast(ulong) result;
            }

            @property void cap_user_rdpmc(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= cap_user_rdpmc_min,
                        "Value is smaller than the minimum value of bitfield 'cap_user_rdpmc'");
                assert(v <= cap_user_rdpmc_max,
                        "Value is greater than the maximum value of bitfield 'cap_user_rdpmc'");
                _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res = cast(
                        typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res))((_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & (
                        -1 - cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) 4U)) | (
                        (cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) v << 2U) & 4U));
            }

            enum ulong cap_user_rdpmc_min = cast(ulong) 0U;
            enum ulong cap_user_rdpmc_max = cast(ulong) 1U;
            @property ulong cap_user_time() @safe pure nothrow @nogc const
            {
                auto result = (
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & 8U) >> 3U;
                return cast(ulong) result;
            }

            @property void cap_user_time(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= cap_user_time_min,
                        "Value is smaller than the minimum value of bitfield 'cap_user_time'");
                assert(v <= cap_user_time_max,
                        "Value is greater than the maximum value of bitfield 'cap_user_time'");
                _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res = cast(
                        typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res))((_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & (
                        -1 - cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) 8U)) | (
                        (cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) v << 3U) & 8U));
            }

            enum ulong cap_user_time_min = cast(ulong) 0U;
            enum ulong cap_user_time_max = cast(ulong) 1U;
            @property ulong cap_user_time_zero() @safe pure nothrow @nogc const
            {
                auto result = (
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & 16U) >> 4U;
                return cast(ulong) result;
            }

            @property void cap_user_time_zero(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= cap_user_time_zero_min,
                        "Value is smaller than the minimum value of bitfield 'cap_user_time_zero'");
                assert(v <= cap_user_time_zero_max,
                        "Value is greater than the maximum value of bitfield 'cap_user_time_zero'");
                _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res = cast(
                        typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res))((_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & (
                        -1 - cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) 16U)) | (
                        (cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) v << 4U) & 16U));
            }

            enum ulong cap_user_time_zero_min = cast(ulong) 0U;
            enum ulong cap_user_time_zero_max = cast(ulong) 1U;
            @property ulong cap_____res() @safe pure nothrow @nogc const
            {
                auto result = (_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & 18446744073709551584UL) >> 5U;
                return cast(ulong) result;
            }

            @property void cap_____res(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= cap_____res_min,
                        "Value is smaller than the minimum value of bitfield 'cap_____res'");
                assert(v <= cap_____res_max,
                        "Value is greater than the maximum value of bitfield 'cap_____res'");
                _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res = cast(
                        typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res))((_cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res & (
                        -1 - cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) 18446744073709551584UL)) | (
                        (cast(typeof(
                        _cap_bit0_cap_bit0_is_deprecated_cap_user_rdpmc_cap_user_time_cap_user_time_zero_cap_____res)) v << 5U) & 18446744073709551584UL));
            }

            enum ulong cap_____res_min = cast(ulong) 0U;
            enum ulong cap_____res_max = cast(ulong) 576460752303423487UL;
        }
    }

    ushort pmc_width;
    ushort time_shift;
    uint time_mult;
    ulong time_offset;
    ulong time_zero;
    uint size;

    ubyte[948] __reserved;
    ulong data_head;
    ulong data_tail;
    ulong data_offset;
    ulong data_size;
    ulong aux_head;
    ulong aux_tail;
    ulong aux_offset;
    ulong aux_size;
}

enum PERF_RECORD_MISC_CPUMODE_MASK = 7 << 0;
enum PERF_RECORD_MISC_CPUMODE_UNKNOWN = 0 << 0;
enum PERF_RECORD_MISC_KERNEL = 1 << 0;
enum PERF_RECORD_MISC_USER = 2 << 0;
enum PERF_RECORD_MISC_HYPERVISOR = 3 << 0;
enum PERF_RECORD_MISC_GUEST_KERNEL = 4 << 0;
enum PERF_RECORD_MISC_GUEST_USER = 5 << 0;

enum PERF_RECORD_MISC_PROC_MAP_PARSE_TIMEOUT = 1 << 12;

enum PERF_RECORD_MISC_MMAP_DATA = 1 << 13;
enum PERF_RECORD_MISC_COMM_EXEC = 1 << 13;
enum PERF_RECORD_MISC_SWITCH_OUT = 1 << 13;

enum PERF_RECORD_MISC_EXACT_IP = 1 << 14;

enum PERF_RECORD_MISC_EXT_RESERVED = 1 << 15;

struct perf_event_header
{
    uint type;
    ushort misc;
    ushort size;
}

struct perf_ns_link_info
{
    ulong dev;
    ulong ino;
}

enum
{
    NET_NS_INDEX = 0,
    UTS_NS_INDEX = 1,
    IPC_NS_INDEX = 2,
    PID_NS_INDEX = 3,
    USER_NS_INDEX = 4,
    MNT_NS_INDEX = 5,
    CGROUP_NS_INDEX = 6,

    NR_NAMESPACES = 7
}

enum perf_event_type
{
    PERF_RECORD_MMAP = 1,
    PERF_RECORD_LOST = 2,
    PERF_RECORD_COMM = 3,
    PERF_RECORD_EXIT = 4,
    PERF_RECORD_THROTTLE = 5,
    PERF_RECORD_UNTHROTTLE = 6,
    PERF_RECORD_FORK = 7,
    PERF_RECORD_READ = 8,
    PERF_RECORD_SAMPLE = 9,
    PERF_RECORD_MMAP2 = 10,
    PERF_RECORD_AUX = 11,
    PERF_RECORD_ITRACE_START = 12,
    PERF_RECORD_LOST_SAMPLES = 13,
    PERF_RECORD_SWITCH = 14,
    PERF_RECORD_SWITCH_CPU_WIDE = 15,
    PERF_RECORD_NAMESPACES = 16,

    PERF_RECORD_MAX = 17
}

enum PERF_MAX_STACK_DEPTH = 127;
enum PERF_MAX_CONTEXTS_PER_STACK = 8;

enum perf_callchain_context
{
    PERF_CONTEXT_HV = cast(ulong)-32,
    PERF_CONTEXT_KERNEL = cast(ulong)-128,
    PERF_CONTEXT_USER = cast(ulong)-512,

    PERF_CONTEXT_GUEST = cast(ulong)-2048,
    PERF_CONTEXT_GUEST_KERNEL = cast(ulong)-2176,
    PERF_CONTEXT_GUEST_USER = cast(ulong)-2560,

    PERF_CONTEXT_MAX = cast(ulong)-4095
}

enum PERF_AUX_FLAG_TRUNCATED = 0x01;
enum PERF_AUX_FLAG_OVERWRITE = 0x02;
enum PERF_AUX_FLAG_PARTIAL = 0x04;
enum PERF_AUX_FLAG_COLLISION = 0x08;

enum PERF_FLAG_FD_NO_GROUP = 1UL << 0;
enum PERF_FLAG_FD_OUTPUT = 1UL << 1;
enum PERF_FLAG_PID_CGROUP = 1UL << 2;
enum PERF_FLAG_FD_CLOEXEC = 1UL << 3;

version (LittleEndian)
{
    union perf_mem_data_src
    {
        ulong val;

        struct
        {

            private ulong _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd;
            @property ulong mem_op() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 31U) >> 0U;
                return cast(ulong) result;
            }

            @property void mem_op(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_op_min,
                        "Value is smaller than the minimum value of bitfield 'mem_op'");
                assert(v <= mem_op_max,
                        "Value is greater than the maximum value of bitfield 'mem_op'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 31U))
                        | ((cast(typeof(
                            _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                            << 0U) & 31U));
            }

            enum ulong mem_op_min = cast(ulong) 0U;
            enum ulong mem_op_max = cast(ulong) 31U;
            @property ulong mem_lvl() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 524256U) >> 5U;
                return cast(ulong) result;
            }

            @property void mem_lvl(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_lvl_min,
                        "Value is smaller than the minimum value of bitfield 'mem_lvl'");
                assert(v <= mem_lvl_max,
                        "Value is greater than the maximum value of bitfield 'mem_lvl'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 524256U)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 5U) & 524256U));
            }

            enum ulong mem_lvl_min = cast(ulong) 0U;
            enum ulong mem_lvl_max = cast(ulong) 16383U;
            @property ulong mem_snoop() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 16252928U) >> 19U;
                return cast(ulong) result;
            }

            @property void mem_snoop(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_snoop_min,
                        "Value is smaller than the minimum value of bitfield 'mem_snoop'");
                assert(v <= mem_snoop_max,
                        "Value is greater than the maximum value of bitfield 'mem_snoop'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 16252928U)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 19U) & 16252928U));
            }

            enum ulong mem_snoop_min = cast(ulong) 0U;
            enum ulong mem_snoop_max = cast(ulong) 31U;
            @property ulong mem_lock() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 50331648U) >> 24U;
                return cast(ulong) result;
            }

            @property void mem_lock(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_lock_min,
                        "Value is smaller than the minimum value of bitfield 'mem_lock'");
                assert(v <= mem_lock_max,
                        "Value is greater than the maximum value of bitfield 'mem_lock'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 50331648U)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 24U) & 50331648U));
            }

            enum ulong mem_lock_min = cast(ulong) 0U;
            enum ulong mem_lock_max = cast(ulong) 3U;
            @property ulong mem_dtlb() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 8522825728UL) >> 26U;
                return cast(ulong) result;
            }

            @property void mem_dtlb(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_dtlb_min,
                        "Value is smaller than the minimum value of bitfield 'mem_dtlb'");
                assert(v <= mem_dtlb_max,
                        "Value is greater than the maximum value of bitfield 'mem_dtlb'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 8522825728UL)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 26U) & 8522825728UL));
            }

            enum ulong mem_dtlb_min = cast(ulong) 0U;
            enum ulong mem_dtlb_max = cast(ulong) 127U;
            @property ulong mem_lvl_num() @safe pure nothrow @nogc const
            {
                auto result = (_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 128849018880UL) >> 33U;
                return cast(ulong) result;
            }

            @property void mem_lvl_num(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_lvl_num_min,
                        "Value is smaller than the minimum value of bitfield 'mem_lvl_num'");
                assert(v <= mem_lvl_num_max,
                        "Value is greater than the maximum value of bitfield 'mem_lvl_num'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 128849018880UL)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 33U) & 128849018880UL));
            }

            enum ulong mem_lvl_num_min = cast(ulong) 0U;
            enum ulong mem_lvl_num_max = cast(ulong) 15U;
            @property ulong mem_remote() @safe pure nothrow @nogc const
            {
                auto result = (_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 137438953472UL) >> 37U;
                return cast(ulong) result;
            }

            @property void mem_remote(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_remote_min,
                        "Value is smaller than the minimum value of bitfield 'mem_remote'");
                assert(v <= mem_remote_max,
                        "Value is greater than the maximum value of bitfield 'mem_remote'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 137438953472UL)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 37U) & 137438953472UL));
            }

            enum ulong mem_remote_min = cast(ulong) 0U;
            enum ulong mem_remote_max = cast(ulong) 1U;
            @property ulong mem_snoopx() @safe pure nothrow @nogc const
            {
                auto result = (_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 824633720832UL) >> 38U;
                return cast(ulong) result;
            }

            @property void mem_snoopx(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_snoopx_min,
                        "Value is smaller than the minimum value of bitfield 'mem_snoopx'");
                assert(v <= mem_snoopx_max,
                        "Value is greater than the maximum value of bitfield 'mem_snoopx'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 824633720832UL)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 38U) & 824633720832UL));
            }

            enum ulong mem_snoopx_min = cast(ulong) 0U;
            enum ulong mem_snoopx_max = cast(ulong) 3U;
            @property ulong mem_rsvd() @safe pure nothrow @nogc const
            {
                auto result = (_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & 18446742974197923840UL) >> 40U;
                return cast(ulong) result;
            }

            @property void mem_rsvd(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_rsvd_min,
                        "Value is smaller than the minimum value of bitfield 'mem_rsvd'");
                assert(v <= mem_rsvd_max,
                        "Value is greater than the maximum value of bitfield 'mem_rsvd'");
                _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd = cast(
                        typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd))((_mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd & (
                        -1 - cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) 18446742974197923840UL)) | (
                        (cast(typeof(
                        _mem_op_mem_lvl_mem_snoop_mem_lock_mem_dtlb_mem_lvl_num_mem_remote_mem_snoopx_mem_rsvd)) v
                        << 40U) & 18446742974197923840UL));
            }

            enum ulong mem_rsvd_min = cast(ulong) 0U;
            enum ulong mem_rsvd_max = cast(ulong) 16777215U;

        }
    }
}
else
{
    union perf_mem_data_src
    {
        ulong val;

        struct
        {
            import std.bitmanip : bitfields;

            private ulong _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op;
            @property ulong mem_rsvd() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 16777215U) >> 0U;
                return cast(ulong) result;
            }

            @property void mem_rsvd(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_rsvd_min,
                        "Value is smaller than the minimum value of bitfield 'mem_rsvd'");
                assert(v <= mem_rsvd_max,
                        "Value is greater than the maximum value of bitfield 'mem_rsvd'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 16777215U)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 0U) & 16777215U));
            }

            enum ulong mem_rsvd_min = cast(ulong) 0U;
            enum ulong mem_rsvd_max = cast(ulong) 16777215U;
            @property ulong mem_snoopx() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 50331648U) >> 24U;
                return cast(ulong) result;
            }

            @property void mem_snoopx(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_snoopx_min,
                        "Value is smaller than the minimum value of bitfield 'mem_snoopx'");
                assert(v <= mem_snoopx_max,
                        "Value is greater than the maximum value of bitfield 'mem_snoopx'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 50331648U)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 24U) & 50331648U));
            }

            enum ulong mem_snoopx_min = cast(ulong) 0U;
            enum ulong mem_snoopx_max = cast(ulong) 3U;
            @property ulong mem_remote() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 67108864U) >> 26U;
                return cast(ulong) result;
            }

            @property void mem_remote(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_remote_min,
                        "Value is smaller than the minimum value of bitfield 'mem_remote'");
                assert(v <= mem_remote_max,
                        "Value is greater than the maximum value of bitfield 'mem_remote'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 67108864U)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 26U) & 67108864U));
            }

            enum ulong mem_remote_min = cast(ulong) 0U;
            enum ulong mem_remote_max = cast(ulong) 1U;
            @property ulong mem_lvl_num() @safe pure nothrow @nogc const
            {
                auto result = (
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 2013265920U) >> 27U;
                return cast(ulong) result;
            }

            @property void mem_lvl_num(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_lvl_num_min,
                        "Value is smaller than the minimum value of bitfield 'mem_lvl_num'");
                assert(v <= mem_lvl_num_max,
                        "Value is greater than the maximum value of bitfield 'mem_lvl_num'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 2013265920U)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 27U) & 2013265920U));
            }

            enum ulong mem_lvl_num_min = cast(ulong) 0U;
            enum ulong mem_lvl_num_max = cast(ulong) 15U;
            @property ulong mem_dtlb() @safe pure nothrow @nogc const
            {
                auto result = (_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 272730423296UL) >> 31U;
                return cast(ulong) result;
            }

            @property void mem_dtlb(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_dtlb_min,
                        "Value is smaller than the minimum value of bitfield 'mem_dtlb'");
                assert(v <= mem_dtlb_max,
                        "Value is greater than the maximum value of bitfield 'mem_dtlb'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 272730423296UL)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 31U) & 272730423296UL));
            }

            enum ulong mem_dtlb_min = cast(ulong) 0U;
            enum ulong mem_dtlb_max = cast(ulong) 127U;
            @property ulong mem_lock() @safe pure nothrow @nogc const
            {
                auto result = (_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 824633720832UL) >> 38U;
                return cast(ulong) result;
            }

            @property void mem_lock(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_lock_min,
                        "Value is smaller than the minimum value of bitfield 'mem_lock'");
                assert(v <= mem_lock_max,
                        "Value is greater than the maximum value of bitfield 'mem_lock'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 824633720832UL)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 38U) & 824633720832UL));
            }

            enum ulong mem_lock_min = cast(ulong) 0U;
            enum ulong mem_lock_max = cast(ulong) 3U;
            @property ulong mem_snoop() @safe pure nothrow @nogc const
            {
                auto result = (_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 34084860461056UL) >> 40U;
                return cast(ulong) result;
            }

            @property void mem_snoop(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_snoop_min,
                        "Value is smaller than the minimum value of bitfield 'mem_snoop'");
                assert(v <= mem_snoop_max,
                        "Value is greater than the maximum value of bitfield 'mem_snoop'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 34084860461056UL)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 40U) & 34084860461056UL));
            }

            enum ulong mem_snoop_min = cast(ulong) 0U;
            enum ulong mem_snoop_max = cast(ulong) 31U;
            @property ulong mem_lvl() @safe pure nothrow @nogc const
            {
                auto result = (_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 576425567931334656UL) >> 45U;
                return cast(ulong) result;
            }

            @property void mem_lvl(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_lvl_min,
                        "Value is smaller than the minimum value of bitfield 'mem_lvl'");
                assert(v <= mem_lvl_max,
                        "Value is greater than the maximum value of bitfield 'mem_lvl'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 576425567931334656UL)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 45U) & 576425567931334656UL));
            }

            enum ulong mem_lvl_min = cast(ulong) 0U;
            enum ulong mem_lvl_max = cast(ulong) 16383U;
            @property ulong mem_op() @safe pure nothrow @nogc const
            {
                auto result = (_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & 17870283321406128128UL) >> 59U;
                return cast(ulong) result;
            }

            @property void mem_op(ulong v) @safe pure nothrow @nogc
            {
                assert(v >= mem_op_min,
                        "Value is smaller than the minimum value of bitfield 'mem_op'");
                assert(v <= mem_op_max,
                        "Value is greater than the maximum value of bitfield 'mem_op'");
                _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op = cast(
                        typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op))((_mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op & (
                        -1 - cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) 17870283321406128128UL)) | (
                        (cast(typeof(
                        _mem_rsvd_mem_snoopx_mem_remote_mem_lvl_num_mem_dtlb_mem_lock_mem_snoop_mem_lvl_mem_op)) v
                        << 59U) & 17870283321406128128UL));
            }

            enum ulong mem_op_min = cast(ulong) 0U;
            enum ulong mem_op_max = cast(ulong) 31U;
        }
    }
}
enum PERF_MEM_OP_NA = 0x01;
enum PERF_MEM_OP_LOAD = 0x02;
enum PERF_MEM_OP_STORE = 0x04;
enum PERF_MEM_OP_PFETCH = 0x08;
enum PERF_MEM_OP_EXEC = 0x10;
enum PERF_MEM_OP_SHIFT = 0;

enum PERF_MEM_LVL_NA = 0x01;
enum PERF_MEM_LVL_HIT = 0x02;
enum PERF_MEM_LVL_MISS = 0x04;
enum PERF_MEM_LVL_L1 = 0x08;
enum PERF_MEM_LVL_LFB = 0x10;
enum PERF_MEM_LVL_L2 = 0x20;
enum PERF_MEM_LVL_L3 = 0x40;
enum PERF_MEM_LVL_LOC_RAM = 0x80;
enum PERF_MEM_LVL_REM_RAM1 = 0x100;
enum PERF_MEM_LVL_REM_RAM2 = 0x200;
enum PERF_MEM_LVL_REM_CCE1 = 0x400;
enum PERF_MEM_LVL_REM_CCE2 = 0x800;
enum PERF_MEM_LVL_IO = 0x1000;
enum PERF_MEM_LVL_UNC = 0x2000;
enum PERF_MEM_LVL_SHIFT = 5;

enum PERF_MEM_REMOTE_REMOTE = 0x01;
enum PERF_MEM_REMOTE_SHIFT = 37;

enum PERF_MEM_LVLNUM_L1 = 0x01;
enum PERF_MEM_LVLNUM_L2 = 0x02;
enum PERF_MEM_LVLNUM_L3 = 0x03;
enum PERF_MEM_LVLNUM_L4 = 0x04;

enum PERF_MEM_LVLNUM_ANY_CACHE = 0x0b;
enum PERF_MEM_LVLNUM_LFB = 0x0c;
enum PERF_MEM_LVLNUM_RAM = 0x0d;
enum PERF_MEM_LVLNUM_PMEM = 0x0e;
enum PERF_MEM_LVLNUM_NA = 0x0f;

enum PERF_MEM_LVLNUM_SHIFT = 33;

enum PERF_MEM_SNOOP_NA = 0x01;
enum PERF_MEM_SNOOP_NONE = 0x02;
enum PERF_MEM_SNOOP_HIT = 0x04;
enum PERF_MEM_SNOOP_MISS = 0x08;
enum PERF_MEM_SNOOP_HITM = 0x10;
enum PERF_MEM_SNOOP_SHIFT = 19;

enum PERF_MEM_SNOOPX_FWD = 0x01;

enum PERF_MEM_SNOOPX_SHIFT = 37;

enum PERF_MEM_LOCK_NA = 0x01;
enum PERF_MEM_LOCK_LOCKED = 0x02;
enum PERF_MEM_LOCK_SHIFT = 24;

enum PERF_MEM_TLB_NA = 0x01;
enum PERF_MEM_TLB_HIT = 0x02;
enum PERF_MEM_TLB_MISS = 0x04;
enum PERF_MEM_TLB_L1 = 0x08;
enum PERF_MEM_TLB_L2 = 0x10;
enum PERF_MEM_TLB_WK = 0x20;
enum PERF_MEM_TLB_OS = 0x40;
enum PERF_MEM_TLB_SHIFT = 26;
struct perf_branch_entry
{

    ulong from;
    ulong to;

    private ulong _mispred_predicted_in_tx_abort_cycles_type_reserved;
    @property ulong mispred() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 1U) >> 0U;
        return cast(ulong) result;
    }

    @property void mispred(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= mispred_min, "Value is smaller than the minimum value of bitfield 'mispred'");
        assert(v <= mispred_max, "Value is greater than the maximum value of bitfield 'mispred'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (
                -1 - cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 1U)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 0U) & 1U));
    }

    enum ulong mispred_min = cast(ulong) 0U;
    enum ulong mispred_max = cast(ulong) 1U;
    @property ulong predicted() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 2U) >> 1U;
        return cast(ulong) result;
    }

    @property void predicted(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= predicted_min,
                "Value is smaller than the minimum value of bitfield 'predicted'");
        assert(v <= predicted_max,
                "Value is greater than the maximum value of bitfield 'predicted'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (
                -1 - cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 2U)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 1U) & 2U));
    }

    enum ulong predicted_min = cast(ulong) 0U;
    enum ulong predicted_max = cast(ulong) 1U;
    @property ulong in_tx() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 4U) >> 2U;
        return cast(ulong) result;
    }

    @property void in_tx(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= in_tx_min, "Value is smaller than the minimum value of bitfield 'in_tx'");
        assert(v <= in_tx_max, "Value is greater than the maximum value of bitfield 'in_tx'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (
                -1 - cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 4U)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 2U) & 4U));
    }

    enum ulong in_tx_min = cast(ulong) 0U;
    enum ulong in_tx_max = cast(ulong) 1U;
    @property ulong abort() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 8U) >> 3U;
        return cast(ulong) result;
    }

    @property void abort(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= abort_min, "Value is smaller than the minimum value of bitfield 'abort'");
        assert(v <= abort_max, "Value is greater than the maximum value of bitfield 'abort'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (
                -1 - cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 8U)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 3U) & 8U));
    }

    enum ulong abort_min = cast(ulong) 0U;
    enum ulong abort_max = cast(ulong) 1U;
    @property ulong cycles() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 1048560U) >> 4U;
        return cast(ulong) result;
    }

    @property void cycles(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= cycles_min, "Value is smaller than the minimum value of bitfield 'cycles'");
        assert(v <= cycles_max, "Value is greater than the maximum value of bitfield 'cycles'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (-1 - cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 1048560U)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 4U) & 1048560U));
    }

    enum ulong cycles_min = cast(ulong) 0U;
    enum ulong cycles_max = cast(ulong) 65535U;
    @property ulong type() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 15728640U) >> 20U;
        return cast(ulong) result;
    }

    @property void type(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= type_min, "Value is smaller than the minimum value of bitfield 'type'");
        assert(v <= type_max, "Value is greater than the maximum value of bitfield 'type'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (-1 - cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 15728640U)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 20U) & 15728640U));
    }

    enum ulong type_min = cast(ulong) 0U;
    enum ulong type_max = cast(ulong) 15U;
    @property ulong reserved() @safe pure nothrow @nogc const
    {
        auto result = (_mispred_predicted_in_tx_abort_cycles_type_reserved & 18446744073692774400UL) >> 24U;
        return cast(ulong) result;
    }

    @property void reserved(ulong v) @safe pure nothrow @nogc
    {
        assert(v >= reserved_min, "Value is smaller than the minimum value of bitfield 'reserved'");
        assert(v <= reserved_max, "Value is greater than the maximum value of bitfield 'reserved'");
        _mispred_predicted_in_tx_abort_cycles_type_reserved = cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved))(
                (_mispred_predicted_in_tx_abort_cycles_type_reserved & (-1 - cast(
                typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) 18446744073692774400UL)) | (
                (cast(typeof(_mispred_predicted_in_tx_abort_cycles_type_reserved)) v << 24U) & 18446744073692774400UL));
    }

    enum ulong reserved_min = cast(ulong) 0U;
    enum ulong reserved_max = cast(ulong) 1099511627775UL;
}
