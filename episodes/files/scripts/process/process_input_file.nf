nextflow.enable.dsl = 2

process NUMLINES {

    input:
    path(reads)

    script:
    """
    printf '${reads} '
    gunzip -c ${reads} | wc -l
    """
}


workflow {
    reads_ch = Channel.fromPath( 'data/yeast/reads/ref*.fq.gz' )
    NUMLINES( reads_ch )
}
