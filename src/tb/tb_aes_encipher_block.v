//======================================================================
//
// tb_aes_encipher_block.v
// -----------------------
// Testbench for the AES encipher block module.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

//------------------------------------------------------------------
// Simulator directives.
//------------------------------------------------------------------
`timescale 1ns/100ps


//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_aes_encipher_block();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 1;
  parameter DUMP_WAIT = 0;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  parameter AES_128_BIT_KEY = 0;
  parameter AES_256_BIT_KEY = 1;

  parameter AES_DECIPHER = 1'b0;
  parameter AES_ENCIPHER = 1'b1;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]   cycle_ctr;
  reg [31 : 0]   error_ctr;
  reg [31 : 0]   tc_ctr;

  reg            tb_clk;
  reg            tb_reset_n;

  reg            tb_next;
  reg            tb_keylen;
  wire           tb_ready;
  wire [3 : 0]   tb_round;
  reg [127 : 0]  tb_round_key;

  wire [31 : 0]  tb_sboxw;
  reg  [31 : 0]  tb_new_sboxw;

  reg [127 : 0]  tb_block;
  wire [127 : 0] tb_new_block;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  aes_encipher_block dut(
                         .clk(tb_clk),
                         .reset_n(tb_reset_n),

                         .next(tb_next),

                         .keylen(tb_keylen),
                         .round(tb_round),
                         .round_key(tb_round_key),

                         .sboxw(tb_sboxw),
                         .new_sboxw(tb_new_sboxw),

                         .block(tb_block),
                         .new_block(tb_new_block),
                         .ready(tb_ready)
                        );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;
      #(CLK_PERIOD);
      if (DEBUG)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state();
    begin
      $display("State of DUT");
      $display("------------");
      $display("ready = 0x%01x, next = 0x%01x, keylen = 0x%01x",
               dut.ready, dut.next, dut.keylen);
      $display("block  = 0x%032x", dut.block);
      $display("new_block    = 0x%016x", dut.new_block);
      $display("");

      $display("round = 0x%01x, round_key = 0x%016x", dut.round, dut.round_key);
      $display("sboxw = 0x%08x, new_sboxw = 0x%08x", dut.sboxw, dut.new_sboxw);
      $display("");

      $display("enc_ctrl = 0x%01x, sword_ctr = 0x%01x, round_ctr = 0x%01x",
               dut.enc_ctrl_reg, dut.sword_ctr_reg, dut.round_ctr_reg);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut();
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim();
    begin
      cycle_ctr    = 0;
      error_ctr    = 0;
      tc_ctr       = 0;

      tb_clk       = 0;
      tb_reset_n   = 1;

      tb_next      = 0;
      tb_keylen    = 0;

      tb_new_sboxw = 32'h00000000;
      tb_round_key = {4{32'h00000000}};
      tb_block     = {4{32'h00000000}};
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // display_test_result()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_result();
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_result


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag in the dut to be set.
  //
  // Note: It is the callers responsibility to call the function
  // when the dut is actively processing and will in fact at some
  // point set the flag.
  //----------------------------------------------------------------
  task wait_ready();
    begin
      while (!tb_ready)
        begin
          #(CLK_PERIOD);
          if (DUMP_WAIT)
            begin
              dump_dut_state();
            end
        end
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // ecb_mode_single_block_test()
  //
  // Perform ECB mode encryption or decryption single block test.
  //----------------------------------------------------------------
  task ecb_mode_single_block_test(input [7 : 0]   tc_number,
                                  input           key_length,
                                  input [127 : 0] block,
                                  input [127 : 0] expected);
   begin
     $display("*** TC %0d ECB mode test started.", tc_number);
     tc_ctr = tc_ctr + 1;

     // Init the cipher with the given key and length.
     tb_keylen = key_length;
     #(2 * CLK_PERIOD);
     wait_ready();

     // Perform encipher och decipher operation on the block.
     tb_block = block;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;

     if (tb_new_block == expected)
       begin
         $display("*** TC %0d successful.", tc_number);
         $display("");
       end
     else
       begin
         $display("*** ERROR: TC %0d NOT successful.", tc_number);
         $display("Expected: 0x%032x", expected);
         $display("Got:      0x%032x", tb_new_block);
         $display("");

         error_ctr = error_ctr + 1;
       end
   end
  endtask // ecb_mode_single_block_test


  //----------------------------------------------------------------
  // tb_aes_encipher_block
  // The main test functionality.
  //
  // Test cases taken from NIST SP 800-38A:
  // http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
  //----------------------------------------------------------------
  initial
    begin : tb_aes_enciphere_block
      reg [127 : 0] nist_aes128_key;
      reg [255 : 0] nist_aes256_key;

      reg [127 : 0] nist_plaintext0;
      reg [127 : 0] nist_plaintext1;
      reg [127 : 0] nist_plaintext2;
      reg [127 : 0] nist_plaintext3;

      reg [127 : 0] nist_ecb_128_enc_expected0;
      reg [127 : 0] nist_ecb_128_enc_expected1;
      reg [127 : 0] nist_ecb_128_enc_expected2;
      reg [127 : 0] nist_ecb_128_enc_expected3;

      reg [127 : 0] nist_ecb_256_enc_expected0;
      reg [127 : 0] nist_ecb_256_enc_expected1;
      reg [127 : 0] nist_ecb_256_enc_expected2;
      reg [127 : 0] nist_ecb_256_enc_expected3;

      nist_aes128_key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
      nist_aes256_key = 255'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;

      nist_plaintext0 = 128'h6bc1bee22e409f96e93d7e117393172a;
      nist_plaintext1 = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
      nist_plaintext2 = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
      nist_plaintext3 = 128'hf69f2445df4f9b17ad2b417be66c3710;

      nist_ecb_128_enc_expected0 = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
      nist_ecb_128_enc_expected1 = 128'hf5d3d58503b9699de785895a96fdbaaf;
      nist_ecb_128_enc_expected2 = 128'h43b1cd7f598ece23881b00e3ed030688;
      nist_ecb_128_enc_expected3 = 128'h7b0c785e27e8ad3f8223207104725dd4;

      nist_ecb_256_enc_expected0 = 255'hf3eed1bdb5d2a03c064b5a7e3db181f8;
      nist_ecb_256_enc_expected1 = 255'h591ccb10d410ed26dc5ba74a31362870;
      nist_ecb_256_enc_expected2 = 255'hb6ed21b99ca6f4f9f153e7b1beafed1d;
      nist_ecb_256_enc_expected3 = 255'h23304b7a39f9f3ff067d8d8f9e24ecc7;


      $display("   -= Testbench for aes encipher block started =-");
      $display("     ============================================");
      $display("");

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();


      display_test_result();
      $display("");
      $display("*** AES encipher block module simulation done. ***");
      $finish;
    end // aes_core_test
endmodule // tb_aes_enciphere_block

//======================================================================
// EOF tb_aes_encipher_block.v
//======================================================================