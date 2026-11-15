// SPDX-License-Identifier: GPL-2.0
/*
 * pfcount -- a page fault counter for one process.
 * CPE 333 Operating Systems, Mini-Project 2 (Virtual Memory), Group 4.
 *
 *   echo <pid> > /proc/pfcount    monitor <pid>'s thread group (0 stops)
 *   cat /proc/pfcount             summary: regions, virtual size, RSS, faults
 *   cat /proc/pfcount_regions     one line per VMA, in the style of
 *                                 /proc/<pid>/maps
 *
 * Two sources of fault counts are reported side by side:
 *
 *   - The kernel's own totals, task->min_flt and task->maj_flt, which
 *     mm_account_fault() (mm/memory.c) increments once per completed fault.
 *     It alone knows whether a fault was major (the page had to be read from
 *     storage) or minor.
 *
 *   - The x86 tracepoints page_fault_user and page_fault_kernel, which fire
 *     on every page fault exception before the fault is handled. They see
 *     each fault as it happens, but carry no minor/major information.
 *
 * Neither tracepoint is exported to modules in 6.8, so they are found by
 * name with for_each_kernel_tracepoint() and attached with
 * tracepoint_probe_register().
 */
#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/atomic.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/mmap_lock.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/pid.h>
#include <linux/proc_fs.h>
#include <linux/rcupdate.h>
#include <linux/sched/mm.h>
#include <linux/sched/signal.h>
#include <linux/sched/task.h>
#include <linux/seq_file.h>
#include <linux/seqlock.h>
#include <linux/string.h>
#include <linux/tracepoint.h>
#include <linux/uaccess.h>

/* Serialises changes of the monitored process and reads of /proc files. */
static DEFINE_MUTEX(pfcount_lock);
/* Thread group being monitored, or NULL. */
static struct pid *monitored;
/* Its lifetime fault totals when monitoring began. */
static unsigned long start_min, start_maj;
/* Tracepoint hits since then. */
static atomic64_t seen_user, seen_kernel;

static struct tracepoint *tp_user, *tp_kernel;

/* ------------------------------------------------------------ probes --- */

/*
 * Called on every page fault in the system, with preemption disabled, so it
 * must be cheap: one pointer comparison, and an increment when it matches.
 * Comparing struct pid pointers rather than numbers cannot be fooled by the
 * pid number being reused after the process exits. The same probe serves
 * both tracepoints; data is the counter it was registered with.
 */
static void on_fault(void *data, unsigned long address,
		     struct pt_regs *regs, unsigned long error_code)
{
	if (task_tgid(current) == READ_ONCE(monitored))
		atomic64_inc(data);
}

static void find_tracepoint(struct tracepoint *tp, void *priv)
{
	if (!strcmp(tp->name, "page_fault_user"))
		tp_user = tp;
	else if (!strcmp(tp->name, "page_fault_kernel"))
		tp_kernel = tp;
}

/* ----------------------------------------------------------- helpers --- */

/*
 * Lifetime fault totals of a whole thread group, summed the way
 * /proc/<pid>/stat sums them: what exited threads left in signal_struct,
 * plus every live thread's own counter. A thread that exits moves its
 * counts into signal_struct and leaves the thread list inside one write
 * section of stats_lock (__exit_signal() in kernel/exit.c), so the sum is
 * retried until no exit happened during it; otherwise that thread could be
 * counted twice or not at all.
 */
static void group_faults(struct task_struct *task, unsigned long *min,
			 unsigned long *maj)
{
	struct signal_struct *sig = task->signal;
	struct task_struct *t;
	unsigned int seq;

	rcu_read_lock();
	do {
		seq = read_seqbegin(&sig->stats_lock);
		*min = sig->min_flt;
		*maj = sig->maj_flt;
		for_each_thread(task, t) {
			*min += t->min_flt;
			*maj += t->maj_flt;
		}
	} while (read_seqretry(&sig->stats_lock, seq));
	rcu_read_unlock();
}

/* Resident pages, summed exactly over the per-CPU counters. */
static unsigned long rss_pages(struct mm_struct *mm)
{
	return get_mm_counter_sum(mm, MM_FILEPAGES) +
	       get_mm_counter_sum(mm, MM_ANONPAGES) +
	       get_mm_counter_sum(mm, MM_SHMEMPAGES);
}

/* The monitored task with a reference held, or NULL if there is none. */
static struct task_struct *get_monitored_task(void)
{
	lockdep_assert_held(&pfcount_lock);
	return monitored ? get_pid_task(monitored, PIDTYPE_TGID) : NULL;
}

/* Explain to the reader why get_monitored_task() returned NULL. */
static void say_why_no_task(struct seq_file *m)
{
	if (!monitored)
		seq_puts(m, "not monitoring: echo <pid> > /proc/pfcount\n");
	else
		seq_printf(m, "pid %d has exited\n", pid_nr(monitored));
}

/* ----------------------------------------------------- /proc/pfcount --- */

static int summary_show(struct seq_file *m, void *v)
{
	struct task_struct *task;
	struct mm_struct *mm;
	struct vm_area_struct *vma;
	unsigned long regions = 0, bytes = 0, rss = 0, min, maj;
	long user, kernel;
	int threads;

	mutex_lock(&pfcount_lock);
	task = get_monitored_task();
	if (!task) {
		say_why_no_task(m);
		goto out;
	}

	mm = get_task_mm(task);
	if (mm) {
		VMA_ITERATOR(vmi, mm, 0);

		/* The VMAs: count them and add up end - start. */
		mmap_read_lock(mm);
		for_each_vma(vmi, vma) {
			regions++;
			bytes += vma->vm_end - vma->vm_start;
		}
		mmap_read_unlock(mm);
		rss = rss_pages(mm);
		mmput(mm);
	}
	group_faults(task, &min, &maj);
	threads = get_nr_threads(task);
	user = atomic64_read(&seen_user);
	kernel = atomic64_read(&seen_kernel);

	seq_printf(m, "pid %d (%s), %d thread%s\n", pid_nr(monitored), task->comm,
		   threads, threads == 1 ? "" : "s");
	seq_printf(m, "  memory regions       : %lu\n", regions);
	seq_printf(m, "  total virtual space  : %lu kB (%lu pages)\n",
		   bytes >> 10, bytes >> PAGE_SHIFT);
	seq_printf(m, "  resident (RSS)       : %lu kB (%lu pages)\n",
		   rss << (PAGE_SHIFT - 10), rss);
	seq_printf(m, "  minor faults         : %-8lu since process start\n", min);
	seq_printf(m, "  major faults         : %-8lu since process start\n", maj);
	seq_puts(m, "  since monitoring started:\n");
	seq_printf(m, "    faults seen        : %-8ld (%ld user mode, %ld kernel mode)\n",
		   user + kernel, user, kernel);
	seq_printf(m, "    minor / major      : %lu / %lu\n",
		   min - start_min, maj - start_maj);
	put_task_struct(task);
out:
	mutex_unlock(&pfcount_lock);
	return 0;
}

static int summary_open(struct inode *inode, struct file *file)
{
	return single_open(file, summary_show, NULL);
}

/*
 * Writing a pid starts monitoring its thread group. Writing the pid already
 * monitored changes nothing, so a second "pfcount <pid>" reads on.
 */
static ssize_t summary_write(struct file *file, const char __user *buf,
			     size_t len, loff_t *ppos)
{
	struct task_struct *task;
	struct pid *pid, *tgid = NULL, *old;
	int nr, err;

	err = kstrtoint_from_user(buf, len, 10, &nr);
	if (err)
		return err;
	if (nr < 0)
		return -EINVAL;
	if (nr > 0) {
		pid = find_get_pid(nr);
		task = pid ? get_pid_task(pid, PIDTYPE_PID) : NULL;
		put_pid(pid);
		if (!task)
			return -ESRCH;
		/* A thread id selects the process it belongs to. */
		tgid = get_pid(task_tgid(task));
		put_task_struct(task);
	}

	mutex_lock(&pfcount_lock);
	if (tgid && tgid == monitored) {
		mutex_unlock(&pfcount_lock);
		put_pid(tgid);
		return len;
	}
	old = monitored;
	/*
	 * Detach first, and wait until no probe can still be counting for
	 * the old process, so the reset below starts from a clean zero.
	 */
	WRITE_ONCE(monitored, NULL);
	synchronize_rcu();
	atomic64_set(&seen_user, 0);
	atomic64_set(&seen_kernel, 0);
	start_min = start_maj = 0;
	if (tgid) {
		task = get_pid_task(tgid, PIDTYPE_TGID);
		if (task) {
			group_faults(task, &start_min, &start_maj);
			put_task_struct(task);
		}
	}
	WRITE_ONCE(monitored, tgid);
	mutex_unlock(&pfcount_lock);
	put_pid(old);
	return len;
}

static const struct proc_ops summary_ops = {
	.proc_open	= summary_open,
	.proc_read	= seq_read,
	.proc_write	= summary_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

/* --------------------------------------------- /proc/pfcount_regions --- */

/* The name /proc/<pid>/maps would show; anonymous regions have none. */
static void region_name(struct seq_file *m, struct vm_area_struct *vma)
{
	/* Special mappings such as [vdso] and [vvar] name themselves. */
	const char *special = vma->vm_ops && vma->vm_ops->name ?
			      vma->vm_ops->name(vma) : NULL;

	if (vma->vm_file) {
		seq_puts(m, "  ");
		seq_file_path(m, vma->vm_file, "\n");
	} else if (special) {
		seq_printf(m, "  %s", special);
	} else if (vma_is_initial_heap(vma)) {
		seq_puts(m, "  [heap]");
	} else if (vma_is_initial_stack(vma)) {
		seq_puts(m, "  [stack]");
	}
}

static int regions_show(struct seq_file *m, void *v)
{
	struct task_struct *task;
	struct mm_struct *mm;
	struct vm_area_struct *vma;

	mutex_lock(&pfcount_lock);
	task = get_monitored_task();
	if (!task) {
		say_why_no_task(m);
		goto out;
	}
	mm = get_task_mm(task);
	put_task_struct(task);
	if (mm) {
		VMA_ITERATOR(vmi, mm, 0);

		mmap_read_lock(mm);
		for_each_vma(vmi, vma) {
			vm_flags_t f = vma->vm_flags;

			seq_printf(m, "%08lx-%08lx %c%c%c%c %8lu kB",
				   vma->vm_start, vma->vm_end,
				   f & VM_READ ? 'r' : '-',
				   f & VM_WRITE ? 'w' : '-',
				   f & VM_EXEC ? 'x' : '-',
				   f & VM_MAYSHARE ? 's' : 'p',
				   (vma->vm_end - vma->vm_start) >> 10);
			region_name(m, vma);
			seq_putc(m, '\n');
		}
		mmap_read_unlock(mm);
		mmput(mm);
	}
out:
	mutex_unlock(&pfcount_lock);
	return 0;
}

static int regions_open(struct inode *inode, struct file *file)
{
	return single_open(file, regions_show, NULL);
}

static const struct proc_ops regions_ops = {
	.proc_open	= regions_open,
	.proc_read	= seq_read,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

/* ------------------------------------------------------- load/unload --- */

/* Detach both probes and wait until none is still running. */
static void detach_probes(void)
{
	tracepoint_probe_unregister(tp_kernel, on_fault, &seen_kernel);
	tracepoint_probe_unregister(tp_user, on_fault, &seen_user);
	tracepoint_synchronize_unregister();
}

static int __init pfcount_init(void)
{
	int err;

	for_each_kernel_tracepoint(find_tracepoint, NULL);
	if (!tp_user || !tp_kernel) {
		pr_err("page fault tracepoints not found\n");
		return -ENOENT;
	}
	err = tracepoint_probe_register(tp_user, on_fault, &seen_user);
	if (err)
		return err;
	err = tracepoint_probe_register(tp_kernel, on_fault, &seen_kernel);
	if (err)
		goto detach_user;

	/* Root only: these files expose any process's address space. */
	err = -ENOMEM;
	if (!proc_create("pfcount", 0600, NULL, &summary_ops))
		goto detach_both;
	if (!proc_create("pfcount_regions", 0400, NULL, &regions_ops))
		goto remove_summary;
	pr_info("attached to tracepoints %s and %s\n",
		tp_user->name, tp_kernel->name);
	return 0;

remove_summary:
	remove_proc_entry("pfcount", NULL);
detach_both:
	tracepoint_probe_unregister(tp_kernel, on_fault, &seen_kernel);
detach_user:
	tracepoint_probe_unregister(tp_user, on_fault, &seen_user);
	tracepoint_synchronize_unregister();
	return err;
}

static void __exit pfcount_exit(void)
{
	remove_proc_entry("pfcount_regions", NULL);
	remove_proc_entry("pfcount", NULL);
	detach_probes();
	put_pid(monitored);
	pr_info("detached\n");
}

module_init(pfcount_init);
module_exit(pfcount_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("CPE 333 Group 4");
MODULE_DESCRIPTION("Page fault counter for one process");
