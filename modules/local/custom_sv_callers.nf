process RUN_CUTESV {
    container "quay.io/biocontainers/cutesv:2.1.1--py310h248e362_0"
    label "wgs"
    publishDir "${params.out_dir}/cutesv", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref_fasta

    output:
    tuple val(meta), path("${meta.sample_name}.cutesv.vcf"), emit: vcf

    script:
    """
    mkdir -p tmp_dir
    cuteSV \\
        ${bam} \\
        ${ref_fasta} \\
        ${meta.sample_name}.cutesv.vcf \\
        tmp_dir \\
        --threads ${task.cpus} \\
        --max_cluster_bias_HDD 100 \\
        --diff_ratio_merging_cluster 0.3
    """
}

process RUN_SVIM {
    container "quay.io/biocontainers/svim:2.0.0--py310hdfd78af_3"
    label "wgs"
    publishDir "${params.out_dir}/svim", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref_fasta

    output:
    tuple val(meta), path("${meta.sample_name}.svim.vcf"), emit: vcf

    script:
    """
    svim alignment \\
        dir_svim \\
        ${bam} \\
        ${ref_fasta}
    
    mv dir_svim/variants.vcf ${meta.sample_name}.svim.vcf
    """
}
