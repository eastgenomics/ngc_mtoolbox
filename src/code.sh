#!/bin/bash
# MToolBox 1.2.1

main() {

    echo "Value of input_bam_file: '${input_bam_file[@]}'"
    echo "Value of input_ref_file: '${input_ref_file[@]}'"
    echo "Value of mtb_docker: '$mtb_docker'"

    time dx-download-all-inputs --parallel

    #Create the folders for bam, mt-reference and output files
    mkdir -p bamfiles
    mkdir -p reffiles
    mkdir -p out/outfiles
    
    #Permissions to write to /home/dnanexus
    chmod a+rwx /home/dnanexus

    #move all downloaded bam files into bamfiles folder
    find ~/in/input_bam_file -type f -name "*" -print0 | xargs -0 -I {} mv {} ~/bamfiles/

    #move all downloaded mt-reference files into reffiles folder
    find ~/in/input_ref_file -type f -name "*" -print0 | xargs -0 -I {} mv {} ~/reffiles/

    gunzip ~/reffiles/hg19RCRS.fa.gz

    
    #Load docker
    docker load -i "$mtb_docker_path"

    mtbcaller_id=$(docker images --format="{{.Repository}} {{.ID}}" | grep "mtoolbox" | cut -d' ' -f2)


    #mkdir -p /src/MToolBox/genome_fasta

    #mv /myfiles/reffiles/*.* /src/MToolBox/genome_fasta/

    
    for BamFileName in bamfiles/*.bam
    do
    	#Remove bamfiles from the BAamFileName variable
        BamFileName=${BamFileName/bamfiles\//}

        #Create temp file to input MToolBox config
        touch /home/dnanexus/input.conf
        echo "mtdb_fasta=chrM.fa" >> /home/dnanexus/input.conf
		echo "hg19_fasta=hg19RCRS.fa" >> /home/dnanexus/input.conf
		echo "mtdb=chrM" >> /home/dnanexus/input.conf
		echo "humandb=hg19RCRS" >> /home/dnanexus/input.conf
		echo "input_path=/myfiles/bamfiles/" >> /home/dnanexus/input.conf
		#echo "output_name=sample" >> /home/dnanexus/input.conf
		echo "input_type=bam" >> /home/dnanexus/input.conf
		echo "ref=RCRS" >> /home/dnanexus/input.conf
		#echo "vcf_name=sample" >> /home/dnanexus/input.conf
		echo "UseMarkDuplicates=true" >> /home/dnanexus/input.conf
		echo "hf_max=0.8" >> /home/dnanexus/input.conf
		echo "hf_min=0.05" >> /home/dnanexus/input.conf

        #print the contents of tmp file
        cat /home/dnanexus/input.conf

        #Run SMNCaller
        docker run -v /home/dnanexus:/myfiles -w /myfiles $mtbcaller_id /src/MToolBox/MToolBox/MToolBox.sh -i /myfiles/input.conf
        
    done
    #Upload results
    dx-upload-all-outputs --parallel
}
