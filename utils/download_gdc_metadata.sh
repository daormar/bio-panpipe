# *- bash -*

########
print_desc()
{
    echo "download_gdc_metadata downloads gdc metadata given a manifest file"
    echo "type \"download_gdc_metadata --help\" to get usage information"
}

########
usage()
{
    echo "download_gdc_metadata  -m <string> [--help]"
    echo ""
    echo "-m <string>      Manifest file"
    echo "--help           Display this help and exit"
}

########
read_pars()
{
    m_given=0
    while [ $# -ne 0 ]; do
        case $1 in
            "--help") usage
                      exit 1
                      ;;
            "-m") shift
                  if [ $# -ne 0 ]; then
                      manifest=$1
                      m_given=1
                  fi
                  ;;
        esac
        shift
    done   
}

########
check_pars()
{
    if [ ${m_given} -eq 0 ]; then   
        echo "Error! -m parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${manifest} ]; then
            echo "Error! file ${manifest} does not exist" >&2
            exit 1
        fi
    fi
}

########
extract_file_id()
{
    local entry=$1
    echo $entry | ${AWK} '{print $1}'
}

########
obtain_file_ids()
{
    local manifest=$1
    local lineno=1
    local file_ids=""
    while read entry; do
        if [ ${lineno} -gt 1 ]; then
            local file_id=`extract_file_id $entry` || return 1
            file_id="\"${file_id}\""
            if [ -z "${file_ids}" ]; then
                file_ids=${file_id}
            else
                file_ids="${file_ids},${file_id}"
            fi
        fi
        lineno=$((lineno + 1))
    done < ${manifest}

    echo ${file_ids}
}

########
obtain_filters()
{
    local manifest=$1
    local file_ids=`obtain_file_ids $manifest`
    
    echo "\"op\":\"in\", \"content\": {\"field\":\"files.file_id\", \"value\": [${file_ids} ] }"
}

########
obtain_num_ids()
{
    local manifest=$1
    wc -l ${manifest} | awk '{printf"%d",$1-1}'
}

########
obtain_payload()
{
    local manifest=$1
    local filters=`obtain_filters ${manifest}`
    local format="TSV"
    local fields="file_id,file_name,cases.submitter_id,cases.case_id,data_category,data_type,cases.samples.tumor_descriptor,cases.samples.tissue_type,cases.samples.sample_type,cases.samples.submitter_id,cases.samples.sample_id,cases.samples.portions.analytes.aliquots.aliquot_id,cases.samples.portions.analytes.aliquots.submitter_id,cases.project.disease_type,cases.project.name,cases.project.primary_site,cases.project.project_id,analysis.workflow_type,cases.demographic.gender,cases.diagnoses.tissue_or_organ_of_origin"
    local size=`obtain_num_ids ${manifest}`
    
    echo "{\"filters\": { ${filters} }, \"format\":\"${format}\" , \"fields\":\"${fields}\" , \"size\":\"${size}\"}"
}

########
process_pars()
{
    tmpfile=`${MKTEMP}`
    trap "rm -f ${tmpfile} 2>/dev/null" EXIT
    obtain_payload ${manifest} > ${tmpfile}
    ${WGET} -O - --header='Content-Type:application/json' --post-file=${tmpfile} 'https://api.gdc.cancer.gov/files' || return 1
}

########

if [ $# -eq 0 ]; then
    print_desc
    exit 1
fi

read_pars $@ || exit 1

check_pars || exit 1

process_pars || exit 1
