# Hw and Labs ECE 9433 =)

## Commands

    #Compile
    vcs -full64 -kdb -sverilog <design>.sv <testbench>.sv -lca -debug_access+all

    #Open Waveforms
    verdi -dbdir simv.daidir/

## Notes

Autograder doesn't accept timescale or timeunits in designs. Don't submit with use dumpvars or timescale, comment them out.

    // `timescale 1ns/1ns

    // initial begin: fsdb_dump
    //   $fsdbDumpfile("dump.fsdb");
    //   $fsdbDumpvars;
    // end: fsdb_dump
