#!/bin/bash
# MToolBox 1.2.1

main() {
    echo "Value of input_bam_file: '${input_bam_file[@]}'"
    echo "Value of input_ref_file: '${input_ref_file[@]}'"
    echo "Value of input_gmap_file: '${input_gmap_file[@]}'"
    echo "Value of mtb_docker: '$mtb_docker'"
    echo "Value of sam_docker: '$sam_docker'"

    time dx-download-all-inputs --parallel

    #Create the folders for bam, gmapfiles, mt-reference and output files
    mkdir -p bamfiles
    mkdir -p reffiles
    mkdir -p chrM
    mkdir -p out/outfiles
    
    #Permissions to write to /home/dnanexus
    chmod a+rwx /home/dnanexus

    #move all downloaded bam files into bamfiles folder
    find ~/in/input_bam_file -type f -name "*" -print0 | xargs -0 -I {} mv {} ~/bamfiles/

    #move all downloaded mt-reference files into reffiles folder
    find ~/in/input_ref_file -type f -name "*" -print0 | xargs -0 -I {} mv {} ~/reffiles/

    #move all downloaded gmapdb files into gmapfiles folder
    find ~/in/input_gmap_file -type f -name "*" -print0 | xargs -0 -I {} mv {} ~/chrM/

    chmod a+rwx ~/bamfiles/
    chmod a+rwx ~/reffiles/
    chmod a+rwx ~/chrM/

    #Load docker
    docker load -i "$mtb_docker_path"

    mtbcaller_id=$(docker images --format="{{.Repository}} {{.ID}}" | grep "mtoolbox" | cut -d' ' -f2)

    docker load -i "$sam_docker_path"

    samcaller_id=$(docker images --format="{{.Repository}} {{.ID}}" | grep "samtools" | cut -d' ' -f2)

    for file in bamfiles/*.bam
    do
        filename="$(basename "$file")";
        BamFileName="${filename%.*}";
        echo "BAMFILE: $BamFileName"

        mkdir -p /home/dnanexus/$BamFileName
        #cp ~/bamfiles/$filename /home/dnanexus/$BamFileName/
        #cp ~/bamfiles/$filename.bai /home/dnanexus/$BamFileName/
        
        #Run samCaller
        docker run -v /home/dnanexus:/mysamfiles -w /mysamfiles $samcaller_id view -b /mysamfiles/bamfiles/$filename MT chrM -o /mysamfiles/$BamFileName/$BamFileName.bam
        
        docker run -v /home/dnanexus:/mysamfiles -w /mysamfiles $samcaller_id index /mysamfiles/$BamFileName/$BamFileName.bam
        #check file copy into folder
        ls -l /home/dnanexus/$BamFileName/$filename

        #Create temp file to input MToolBox config
        touch /home/dnanexus/input.conf
        echo "fasta_path=/myfiles/reffiles/" >> /home/dnanexus/input.conf
        echo "gsnapdb=/myfiles/" >> /home/dnanexus/input.conf
        echo "mtdb_fasta=chrM.fa" >> /home/dnanexus/input.conf
        echo "hg19_fasta=hg19RCRS.fa" >> /home/dnanexus/input.conf
        echo "mtdb=chrM" >> /home/dnanexus/input.conf
        echo "humandb=hg19RCRS" >> /home/dnanexus/input.conf
        echo "input_path=/myfiles/$BamFileName/" >> /home/dnanexus/input.conf
        #echo "output_name=sample" >> /home/dnanexus/input.conf
        echo "input_type=bam" >> /home/dnanexus/input.conf
        echo "ref=RCRS" >> /home/dnanexus/input.conf
        echo "vcf_name=$BamFileName" >> /home/dnanexus/input.conf
        echo "UseMarkDuplicates=true" >> /home/dnanexus/input.conf
        echo "hf_max=0.8" >> /home/dnanexus/input.conf
        echo "hf_min=0.05" >> /home/dnanexus/input.conf

        #print the contents of tmp file
        echo "ConfigNameStart"
        cat /home/dnanexus/input.conf
        echo "ConfigNameEnd"

        #Run SMNCaller
        docker run -v /home/dnanexus:/myfiles -w /myfiles $mtbcaller_id /src/MToolBox/MToolBox/MToolBox.sh -i /myfiles/input.conf

        #copy results files to home dir
        cp /home/dnanexus/$BamFileName/$BamFileName.vcf /home/dnanexus/out/outfiles/$BamFileName.vcf
        cp /home/dnanexus/$BamFileName/prioritized_variants.txt /home/dnanexus/out/outfiles/$BamFileName.prioritized_variants.txt
        cp /home/dnanexus/$BamFileName/mt_classification_best_results.csv /home/dnanexus/out/outfiles/$BamFileName.mt_classification_best_results.csv

        rm /home/dnanexus/input.conf
    done
    #Upload results
    dx-upload-all-outputs --parallel
}
