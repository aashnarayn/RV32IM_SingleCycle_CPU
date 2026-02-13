    .data
array1:
    .byte 0xaa, 0xbb, 0xcc, 0xdd, 0x01,0xff
    
    .text
    .globl _start
_start:
    la x1, array1
    
    #byte-wise load
    lb  x2, 0(x1)
    lbu x3, 4(x1)

    #half-word-wise load
    lh x4, 0(x1)
    lhu x5, 3(x1)
    
    #word-wise load
    lw x6, 2(x1)
    
    #byte-wise store
    li x7, 0x77
    sb x7, 6(x1)
    
    #half-word-wise store
    li x8, 0x2244
    sh x8, 7(x1)
    
    #word-wise store
    sw x6, 12(x1)
    
    #wait forever
end:
    j end
    