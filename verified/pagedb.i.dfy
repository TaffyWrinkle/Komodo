include "pagedb.s.dfy"
include "kom_common.i.dfy"

//-----------------------------------------------------------------------------
// Data Structures
//-----------------------------------------------------------------------------
// computes byte offset of a specific pagedb entry
function method G_PAGEDB_ENTRY(pageno:PageNr): addr
{
    assert WordAligned(PAGEDB_ENTRY_SIZE());
    pageno * PAGEDB_ENTRY_SIZE()
}

// entry = start offset of pagedb entry
function method PAGEDB_ENTRY_TYPE():int      { 0 }
function method PAGEDB_ENTRY_ADDRSPACE():int { 4 }

//-----------------------------------------------------------------------------
// Addrspace Fields
//-----------------------------------------------------------------------------
// addrspc = start address of address space metadata
// TODO requires that this thing is an addrspce?
function method ADDRSPACE_L1PT():int        {  0 }
function method ADDRSPACE_L1PT_PHYS():int   {  4 }
function method ADDRSPACE_REF():int         {  8 }
function method ADDRSPACE_STATE():int       { 12 }
function method ADDRSPACE_SIZE():int        { 16 }

//-----------------------------------------------------------------------------
// Dispatcher Fields
//-----------------------------------------------------------------------------
function method DISPATCHER_ENTERED():int    { 0 }
function method DISPATCHER_ENTRYPOINT():int { 4 }

function method DISP_CTXT_R0():int   { 8 }
function method DISP_CTXT_R1():int   { 12 }
function method DISP_CTXT_R2():int   { 16 }
function method DISP_CTXT_R3():int   { 20 }
function method DISP_CTXT_R4():int   { 24 }
function method DISP_CTXT_R5():int   { 28 }
function method DISP_CTXT_R6():int   { 32 }
function method DISP_CTXT_R7():int   { 36 }
function method DISP_CTXT_R8():int   { 40 }
function method DISP_CTXT_R9():int   { 44 }
function method DISP_CTXT_R10():int  { 48 }
function method DISP_CTXT_R11():int  { 52 }
function method DISP_CTXT_R12():int  { 56 }
function method DISP_CTXT_LR():int   { 60 }
function method DISP_CTXT_SP():int   { 64 }
function method DISP_CTXT_PC():int   { 68 }
function method DISP_CTXT_PSR():int  { 72 }

//-----------------------------------------------------------------------------
// Page Types
//-----------------------------------------------------------------------------
function method KOM_PAGE_FREE():int         { 0 }
function method KOM_PAGE_ADDRSPACE():int    { 1 }
function method KOM_PAGE_DISPATCHER():int   { 2 }
function method KOM_PAGE_L1PTABLE():int     { 3 }
function method KOM_PAGE_L2PTABLE():int     { 4 }
function method KOM_PAGE_DATA():int         { 5 }

//-----------------------------------------------------------------------------
// Address Space States
//-----------------------------------------------------------------------------
function method KOM_ADDRSPACE_INIT():int    { 0 }
function method KOM_ADDRSPACE_FINAL():int   { 1 }
function method KOM_ADDRSPACE_STOPPED():int { 2 }

//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------

predicate memContainsPage(page: memmap, p:PageNr)
{
    forall m:addr :: addrInPage(m,p) ==> m in page
}

function extractPage(s:memstate, p:PageNr): memmap
    requires SaneMem(s)
    ensures memContainsPage(extractPage(s,p), p)
{
    reveal_ValidMemState();
    // XXX: expanded addrInPage() to help Dafny see a bounded set
    var res := (map m:addr {:trigger addrInPage(m, p), MemContents(s, m)}
        | page_monvaddr(p) <= m < page_monvaddr(p) + PAGESIZE()
        // XXX: this mess seems to be needed to help Dafny see that we have a legit word
        :: var v:word := MemContents(s, m); assert isUInt32(v); v);
    res
}


function extractPageDbEntry(s:memstate, p:PageNr): seq<word>
    requires SaneMem(s)
    ensures |extractPageDbEntry(s,p)| == BytesToWords(PAGEDB_ENTRY_SIZE())
    // ensures forall o | WordAligned(o) && 0 <= o < PAGEDB_ENTRY_SIZE() ::
    //    GlobalWord(s, PageDb(), G_PAGEDB_ENTRY(p) + o)
    //        == extractPageDbEntry(s,p)[BytesToWords(o)]
{
    var fulldb := GlobalFullContents(s, PageDb());
    assert |fulldb| == BytesToWords(G_PAGEDB_SIZE());
    var entrylen := BytesToWords(PAGEDB_ENTRY_SIZE());
    //fulldb[p*entrylen..p*entrylen+entrylen]
    fulldb[p*BytesToWords(PAGEDB_ENTRY_SIZE())..(p+1)*BytesToWords(PAGEDB_ENTRY_SIZE())]
}

predicate pageDbCorresponds(s:memstate, pagedb:PageDb)
    requires SaneMem(s)
    requires wellFormedPageDb(pagedb)
{
    // XXX: unpack the entry and page contents here to help dafny see
    // that we have no other dependencies on the state
    var db := (map p | 0 <= p < KOM_SECURE_NPAGES() :: extractPageDbEntry(s,p));
    var secpages := (map p | 0 <= p < KOM_SECURE_NPAGES() :: extractPage(s,p));
    forall p {:trigger validPageNr(p)} | validPageNr(p) :: 
        pageDbEntryCorresponds(pagedb[p], db[p])
            && pageContentsCorresponds(p, pagedb[p], secpages[p])
}

predicate pageDbCorrespondsExcluding(s:memstate, pagedb:PageDb, modifiedPage:PageNr)
    requires SaneMem(s)
    requires wellFormedPageDb(pagedb)
{
    forall p {:trigger validPageNr(p)} :: validPageNr(p) && p != modifiedPage
        ==> (pageDbEntryCorresponds(pagedb[p], extractPageDbEntry(s, p))
            && pageContentsCorresponds(p, pagedb[p], extractPage(s, p)))
}

predicate pageDbCorrespondsExcludingSet(s:memstate, pagedb:PageDb, 
    trashed:set<PageNr>)
    requires SaneMem(s)
    requires wellFormedPageDb(pagedb)
{
    forall p {:trigger validPageNr(p)} | validPageNr(p) && p !in trashed  ::
        (pageDbEntryCorresponds(pagedb[p], extractPageDbEntry(s, p))
            && pageContentsCorresponds(p, pagedb[p], extractPage(s, p)))
}

predicate pageDbCorrespondsOnly(s:memstate, pagedb:PageDb, p:PageNr)
    requires SaneMem(s)
    requires wellFormedPageDb(pagedb)
{
    pageDbEntryCorresponds(pagedb[p], extractPageDbEntry(s, p))
    && pageContentsCorresponds(p, pagedb[p], extractPage(s, p))
}

predicate {:opaque} pageDbEntryCorresponds(e:PageDbEntry, entryWords:seq<word>)
    requires |entryWords| == BytesToWords(PAGEDB_ENTRY_SIZE())
    requires wellFormedPageDbEntry(e)
{
    pageDbEntryTypeVal(e) == entryWords[BytesToWords(PAGEDB_ENTRY_TYPE())]
    && match e {
        case PageDbEntryFree => true
        case PageDbEntryTyped(addrspace, entry) =>
            entryWords[BytesToWords(PAGEDB_ENTRY_ADDRSPACE())]
                == page_monvaddr(addrspace)
    }
}

predicate {:opaque} pageContentsCorresponds(p:PageNr, e:PageDbEntry, page:memmap)
    requires memContainsPage(page, p)
    requires wellFormedPageDbEntry(e)
{
    e.PageDbEntryFree? || (e.PageDbEntryTyped? && (
        var et := e.entry;
        assert wellFormedPageDbEntryTyped(et);
        (et.Addrspace? && pageDbAddrspaceCorresponds(p, et, page))
        || (et.Dispatcher? && pageDbDispatcherCorresponds(p, et, page))
        || (et.L1PTable? && pageDbL1PTableCorresponds(p, et, page))
        || (et.L2PTable? && pageDbL2PTableCorresponds(p, et, page))
        || et.DataPage?))
}

predicate {:opaque} pageDbAddrspaceCorresponds(p:PageNr, e:PageDbEntryTyped, page:memmap)
    requires memContainsPage(page, p)
    requires e.Addrspace?
{
    var base := page_monvaddr(p);
    assert base in page;
    page[base + ADDRSPACE_L1PT()] == page_monvaddr(e.l1ptnr)
    && page[base + ADDRSPACE_L1PT_PHYS()] == page_paddr(e.l1ptnr)
    && page[base + ADDRSPACE_REF()] == e.refcount
    && page[base + ADDRSPACE_STATE()] == pageDbAddrspaceStateVal(e.state)
}

function  to_i(b:bool):int { if(b) then 1 else 0 }

predicate {:opaque} pageDbDispatcherCorresponds(p:PageNr, e:PageDbEntryTyped, page:memmap)
    requires memContainsPage(page, p)
    requires wellFormedPageDbEntryTyped(e) && e.Dispatcher?
{
    var base := page_monvaddr(p);
    assert base in page;
    assert wellformedDispatcherContext(e.ctxt);
    page[base + DISPATCHER_ENTERED()] == to_i(e.entered)
    && page[base + DISPATCHER_ENTRYPOINT()] == e.entrypoint
    && page[base + DISP_CTXT_PC()]  == e.ctxt.pc
    && page[base + DISP_CTXT_PSR()] == e.ctxt.cpsr
    && page[base + DISP_CTXT_LR()]  == e.ctxt.regs[LR(User)]
    && page[base + DISP_CTXT_SP()]  == e.ctxt.regs[SP(User)]
    && page[base + DISP_CTXT_R0()]  == e.ctxt.regs[R0]
    && page[base + DISP_CTXT_R1()]  == e.ctxt.regs[R1]
    && page[base + DISP_CTXT_R2()]  == e.ctxt.regs[R2]
    && page[base + DISP_CTXT_R3()]  == e.ctxt.regs[R3]
    && page[base + DISP_CTXT_R4()]  == e.ctxt.regs[R4]
    && page[base + DISP_CTXT_R5()]  == e.ctxt.regs[R5]
    && page[base + DISP_CTXT_R6()]  == e.ctxt.regs[R6]
    && page[base + DISP_CTXT_R7()]  == e.ctxt.regs[R7]
    && page[base + DISP_CTXT_R8()]  == e.ctxt.regs[R8]
    && page[base + DISP_CTXT_R9()]  == e.ctxt.regs[R9]
    && page[base + DISP_CTXT_R10()] == e.ctxt.regs[R10]
    && page[base + DISP_CTXT_R11()] == e.ctxt.regs[R11]
    && page[base + DISP_CTXT_R12()] == e.ctxt.regs[R12]
}

function ARM_L1PTE(paddr: word): word
    requires paddr % ARM_L2PTABLE_BYTES() == 0
    //ensures ValidAbsL1PTEWord(ARM_L1PTE(paddr))
{
    BitwiseOr(paddr, 1) // type = 1, pxn = 0, ns = 0, domain = 0
}

function ARM_L2PTE(paddr: word, write: bool, exec: bool): word
    requires PageAligned(paddr)
    //ensures ValidAbsL2PTEWord(ARM_L2PTE(paddr, write, exec))
{
    var nxbits:bv32 := if exec then 0 else ARM_L2PTE_NX_BIT();
    var robits:bv32 := if write then 0 else ARM_L2PTE_RO_BIT();
    BitsAsWord(BitOr(WordAsBits(paddr), BitOr(
        BitOr(ARM_L2PTE_CONST_BITS() | 0x2, nxbits), robits)))
}

function mkL1Pte(e: Maybe<PageNr>, subpage:int): int
    requires 0 <= subpage < 4
    //ensures ValidAbsL1PTEWord(mkL1Pte(e, subpage))
{
    match e
        case Nothing => 0
        case Just(pgNr) =>
            assert ARM_L2PTABLE_BYTES() == 0x400; // grumble
            ARM_L1PTE(page_paddr(pgNr) + subpage * ARM_L2PTABLE_BYTES())
}

function l1pteoffset(base: addr, i: int, j: int): addr
    requires base < 0xfffff000
    requires 0 <= i < NR_L1PTES() && 0 <= j < 4
{
    base + 4 * (i * 4 + j)
}

predicate {:opaque} pageDbL1PTableCorresponds(p:PageNr, e:PageDbEntryTyped,
                                              page:memmap)
    requires memContainsPage(page, p)
    requires e.L1PTable? && wellFormedPageDbEntryTyped(e)
{
    var base := page_monvaddr(p);
    forall i, j :: 0 <= i < NR_L1PTES() && 0 <= j < 4
        ==> page[l1pteoffset(base, i, j)] == mkL1Pte(e.l1pt[i], j)
}

function mkL2Pte(pte: L2PTE): word
    //ensures ValidAbsL2PTEWord(mkL2Pte(pte))
{
    match pte
        case SecureMapping(pg, w, x) => ARM_L2PTE(page_paddr(pg), w, x)
        case InsecureMapping(ipg, w) => (
            assert validInsecurePageNr(ipg);
            assert PAGESIZE() == 0x1000; // sigh
            var pa := ipg * PAGESIZE();
            assert PageAligned(pa); // double sigh
            ARM_L2PTE(pa, w, false))
        case NoMapping => 0
}

predicate {:opaque} pageDbL2PTableCorresponds(p:PageNr, e:PageDbEntryTyped,
                                              page:memmap)
    requires memContainsPage(page, p)
    requires e.L2PTable? && wellFormedPageDbEntryTyped(e)
{
    var base := page_monvaddr(p);
    forall i :: 0 <= i < NR_L2PTES() ==>
        var a := base + WordsToBytes(i);
        assert a in page;
        page[a] == mkL2Pte(e.l2pt[i])
}

function pageDbEntryTypeVal(e: PageDbEntry): word
{
    if e.PageDbEntryFree? then KOM_PAGE_FREE()
    else match e.entry {
        case Addrspace(l1pt, ref, state) => KOM_PAGE_ADDRSPACE()
        case Dispatcher(ep, entered, ctxt) => KOM_PAGE_DISPATCHER()
        case L1PTable(pt) => KOM_PAGE_L1PTABLE()
        case L2PTable(pt) => KOM_PAGE_L2PTABLE()
        case DataPage => KOM_PAGE_DATA()
    }
}

function pageDbAddrspaceStateVal(s: AddrspaceState): word
{
    match s {
    case InitState => KOM_ADDRSPACE_INIT()
    case FinalState => KOM_ADDRSPACE_FINAL()
    case StoppedState => KOM_ADDRSPACE_STOPPED()
    }
}

//-----------------------------------------------------------------------------
// Common lemmas
//-----------------------------------------------------------------------------

lemma globalUnmodifiedImpliesCorrespondingPreserved(d:PageDb,m:memstate,m':memstate)
    requires SaneMem(m) && SaneMem(m') && validPageDb(d)
    requires (reveal_ValidMemState();
        m.globals[PageDb()] == m'.globals[PageDb()] &&
        m.addresses == m'.addresses)
    requires pageDbCorresponds(m,  d)
    ensures  pageDbCorresponds(m', d)
{
    reveal_PageDb();
    reveal_ValidMemState();
    reveal_pageDbEntryCorresponds();
    reveal_pageContentsCorresponds();
   
    forall ( p | validPageNr(p) )
        ensures pageDbEntryCorresponds(d[p], extractPageDbEntry(m',p));
        ensures pageContentsCorresponds(p, d[p], extractPage(m', p));
    {
        assert extractPageDbEntry(m, p) == extractPageDbEntry(m', p);
        PageDbCorrespondsImpliesEntryCorresponds(m, d, p);
        assert pageDbEntryCorresponds(d[p], extractPageDbEntry(m, p));
        
        assert extractPage(m, p) == extractPage(m', p);
        assert pageContentsCorresponds(p, d[p], extractPage(m, p));
    }

}

lemma ValidPageDbImpliesValidAddrspace(d:PageDb, n:PageNr)
    requires validPageDb(d)
    requires isAddrspace(d, n)
    ensures validAddrspace(d, n)
{
    reveal_validPageDb();
    assert validPageDbEntryTyped(d, n);
}

lemma PageDbCorrespondsImpliesEntryCorresponds(s:memstate, d:PageDb, n:PageNr)
    requires SaneMem(s)
    requires wellFormedPageDb(d)
    requires pageDbCorresponds(s, d)
    ensures pageDbEntryCorresponds(d[n], extractPageDbEntry(s, n))
{
}

lemma AllButOnePagePreserving(n:PageNr,s:state,r:state)
    requires SaneState(s) && SaneState(r)
    requires MemPreservingExcept(s, r, page_monvaddr(n),
                                 page_monvaddr(n) + PAGESIZE())
    ensures forall p :: validPageNr(p) && p != n
        ==> extractPage(s.m, p) == extractPage(r.m, p)
{
    forall (p, a:addr | validPageNr(p) && p != n && addrInPage(a, p))
        ensures MemContents(s.m, a) == MemContents(r.m, a)
        {}
}


lemma extractPageDbToAbstract(s:memstate, p:PageNr)
    requires SaneMem(s)
    ensures forall o | WordAligned(o) && 0 <= o < PAGEDB_ENTRY_SIZE() ::
        GlobalWord(s, PageDb(), G_PAGEDB_ENTRY(p) + o)
            == extractPageDbEntry(s,p)[BytesToWords(o)]
{
}

lemma extractPageDbToAbstractOne(s:memstate, p:PageNr, o:int)
    requires SaneMem(s)
    requires WordAligned(o) && 0 <= o < PAGEDB_ENTRY_SIZE()
    ensures GlobalWord(s, PageDb(), G_PAGEDB_ENTRY(p) + o)
        == extractPageDbEntry(s,p)[BytesToWords(o)]
{
}

/*
lemma allOnlyCorrespondImpliesCorresponds(s:memstate,d:PageDb)
    requires SaneMem(s)
    ensures pageDbCorresponds(s,d)
{
    reveal_pageDbEntryCorresponds
}
*/

lemma lemma_SameMemAndGlobalsPreservesPageDb(s:state, s':state, pagedb:PageDb)
    requires SaneState(s) && SaneState(s')
    requires validPageDb(pagedb)
    requires pageDbCorresponds(s.m, pagedb)
    requires NonStackMemPreserving(s,s')
    requires GlobalsInvariant(s,s')
    ensures pageDbCorresponds(s'.m, pagedb)
{
    lemma_SameMemAndGlobalsPreservesPageDb'(s,s',pagedb);
}

lemma lemma_SameMemAndGlobalsPreservesPageDb'(s:state, s':state, pagedb:PageDb)
    requires SaneState(s) && SaneState(s')
    requires validPageDb(pagedb)
    requires pageDbCorresponds(s.m, pagedb)
    requires NonStackMemPreserving(s,s')
    requires GlobalFullContents(s.m, PageDb()) == GlobalFullContents(s'.m, PageDb())
    ensures pageDbCorresponds(s'.m, pagedb)
{
    assert forall p :: validPageNr(p) ==> extractPage(s.m, p) == extractPage(s'.m, p);
}
