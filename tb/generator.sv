`ifndef GENERATOR_SV
`define GENERATOR_SV

`include "uart_trans.sv" // Because compiler does not know about transaction class
class generator;
transaction trans;
mailbox mb;
int count = 30; // for initial debugging it generates 30 packets
// Constructor for generator     
// It tells on which location mailbox put data
function new(mailbox mb);
        this.mb = mb;
endfunction

task main();
        repeat(count) begin
            trans = new(); 
            
            if(!trans.randomize()) begin 
                $fatal("Generator: Randomization Failed!");
            end
            
            trans.display("Generator"); 
            
            mb.put(trans); 
        end
    endtask

endclass

`endif
