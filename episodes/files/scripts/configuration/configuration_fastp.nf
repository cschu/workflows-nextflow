// configuration_fastp.nf
nextflow.enable.dsl = 2

params.input = "data/yeast/reads/ref1_1.fq.gz"

workflow {
    FASTP( Channel.fromPath( params.input )).view()
}

process FASTP {

   input:
   path(reads)

   output:
   stdout

   script:
   """
   fastp -A -i ${reads} -o out.fq 2>&1
   """
}

