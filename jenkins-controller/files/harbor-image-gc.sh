#!/bin/bash
#
# Remove docker images that are not used in the current version of the chart.

git_id='gitlab-ci-token'
git_password='WjkhjLNzLUL76GBxTv9s'
registry_id='admin'
registry_password='wlwndgo'
registry_server="100.100.103.167"
build_envs=("dev" "staging" "prod")
tmp_dir="/tmp/helm-charts"

declare -A repo_map
declare -A match_map

deploy_images=()
build_images=()

function initiailize()
{
    repo_map["ne-core"]="http://${git_id}:${git_password}@100.100.103.5/IPRON-NE/devops/helm/core-charts.git"
    repo_map["ne-media"]="http://${git_id}:${git_password}@100.100.103.5/IPRON-NE/devops/helm/media-charts.git"
    repo_map["ne-backend"]="http://${git_id}:${git_password}@100.100.103.5/IPRON-NE/devops/helm/backend-charts.git"
    repo_map["ne-frontend"]="http://${git_id}:${git_password}@100.100.103.5/IPRON-NE/devops/helm/frontend-charts.git"
}

function clone_repository()
{
    local package=$1
    local repo_addr=$2

    mkdir -p ${tmp_dir}
    git clone ${repo_addr} ${tmp_dir}/${package}
}

function clean_repository()
{
    rm -rf ${tmp_dir}
}

function clear_match_map()
{
    for image_tag in ${!match_map[@]}; do
        unset match_map[${image_tag}]
    done
}

function print_deploy_image()
{
    echo "deploy_images:"
    for image in ${deploy_images[@]}; do
        echo ${image}
    done
    echo ""
}

function print_build_image()
{
    echo "build_images:"
    for image in ${build_images[@]}; do
        echo ${image}
    done
    echo ""
}

function get_image_name()
{
    local chart_file=$1
    local values_file=$2

    name=`yq e .image.name ${values_file}`
    if [[ -z ${name} || ${name} == null ]]; then
        name=`yq e .name ${chart_file}`
    fi
    echo ${name}
}

function get_depoly_images_from_all_envs()
{
    local chart_version_dir=$1

    for env in ${build_envs[@]}; do
        values_file="${chart_version_dir}variants/${env}/values.yaml"
        image_tag=`yq e .image.tag ${values_file} 2>/dev/null`
        if [[ -z ${image_tag} || ${image_tag} == null ]]; then
            continue
        fi
        deploy_images+=(${image_tag})
    done
}

function get_build_images_from_registry()
{
    local package=$1
    local image_name=$2

    response=`curl --insecure -s -X GET "https://${registry_server}/api/v2.0/projects/${package}/repositories/${image_name}/artifacts?with_tag=true" -H "accept: application/json"`
    for index in $(seq 0 20); do
        image_tag=`echo ${response} | jq -ce ".[${index}]" 2>/dev/null | jq -e '.tags[].name' 2>/dev/null`
        if [[ -z ${image_tag} || ${image_tag} == null ]]; then
            continue
        fi
        image_tag=`echo "$image_tag" | sed 's/"//g'`
        build_images+=(${image_tag})
    done
}

function extract_remove_image_tag()
{
    for image in ${build_images[@]}; do
        match_map[${image}]=1
    done
    for image in ${deploy_images[@]}; do
        match_map[${image}]=0
    done
}

function remove_image_to_registry()
{
    local package=$1
    local image_name=$2

    echo "remove:"
    for key in ${!match_map[@]}; do
        if [[ ${match_map[${key}]} -eq 1 ]]; then
            curl --insecure -u ${registry_id}:${registry_password} -X DELETE "https://${registry_server}/api/v2.0/projects/${package}/repositories/${image_name}/artifacts/${key}" -H "accept: application/json"
        fi
    done
}

function proc_chart_job()
{
    local package=$1

    for chart in ${tmp_dir}/${package}/charts/*; do
        version_dirs=`ls -d ${chart}/*/`
        version=`cat ${chart}/VERSION`
        current_chart_file=${chart}/${version}/Chart.yaml
        current_values_file=${chart}/${version}/values.yaml
        image_name=$(get_image_name ${current_chart_file} ${current_values_file})

        get_depoly_images_from_all_envs ${version_dirs}
        get_build_images_from_registry ${package} ${image_name}

        echo ">> image_name: ${image_name}"
        echo "============================================="
        print_deploy_image
        print_build_image
        extract_remove_image_tag
        remove_image_to_registry ${package} ${image_name}
        echo ""
        echo "============================================="
        echo ""

        unset deploy_images
        unset build_images
        clear_match_map
    done
}

initiailize
for package in ${!repo_map[@]}; do
    repo_addr=${repo_map[${package}]}
    echo "repo_addr: ${repo_addr}"
    clone_repository ${package} ${repo_addr}
    proc_chart_job ${package}
done
clean_repository