#!/bin/bash
# ============================================================================
# JENKINS INFRASTRUCTURE TEST SCRIPT
# ============================================================================
# PURPOSE: Test ASG scaling, EFS mounting, and SSM connectivity
# USAGE: ./scripts/test-infrastructure.sh [test-type]
#
# TEST TYPES:
#   all         - Run all tests (default)
#   ssm         - Test SSM connectivity only
#   asg         - Test ASG scaling only
#   efs         - Test EFS mounting only
#   health      - Quick health check
#
# PREREQUISITES:
#   - AWS CLI configured with appropriate permissions
#   - Terraform outputs available (run from terraform directory)
#   - jq installed for JSON parsing
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
AWS_REGION="${AWS_REGION:-eu-west-1}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

# Get Terraform output value
get_tf_output() {
    local output_name=$1
    cd "$TERRAFORM_DIR"
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

# Get instance IDs from ASG
get_asg_instances() {
    local asg_name=$1
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$asg_name" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text
}

# Wait for instance to be running
wait_for_instance() {
    local instance_id=$1
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for instance $instance_id to be running..."
    
    while [ $attempt -lt $max_attempts ]; do
        state=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --region "$AWS_REGION" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text 2>/dev/null || echo "pending")
        
        if [ "$state" == "running" ]; then
            log_success "Instance $instance_id is running"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 10
    done
    
    log_error "Timeout waiting for instance $instance_id"
    return 1
}

# ============================================================================
# TEST: SSM CONNECTIVITY
# ============================================================================

test_ssm_connectivity() {
    log_header "Testing SSM Session Manager Connectivity"
    
    local controller_asg=$(get_tf_output "controller_asg_name")
    local agent_asg=$(get_tf_output "agent_asg_name")
    
    if [ -z "$controller_asg" ]; then
        log_error "Could not get controller ASG name from Terraform outputs"
        return 1
    fi
    
    log_info "Controller ASG: $controller_asg"
    log_info "Agent ASG: $agent_asg"
    
    # Get controller instances
    local controller_instances=$(get_asg_instances "$controller_asg")
    
    if [ -z "$controller_instances" ]; then
        log_warning "No controller instances found"
        return 1
    fi
    
    log_info "Found controller instances: $controller_instances"
    
    # Test SSM connectivity for first controller
    local first_controller=$(echo "$controller_instances" | awk '{print $1}')
    
    log_info "Testing SSM connectivity to controller: $first_controller"
    
    # Check if instance is SSM managed
    local ssm_status=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$first_controller" \
        --region "$AWS_REGION" \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null || echo "NotFound")
    
    if [ "$ssm_status" == "Online" ]; then
        log_success "Controller $first_controller is SSM managed and online!"
        
        # Run a simple command via SSM
        log_info "Running test command via SSM..."
        aws ssm send-command \
            --instance-ids "$first_controller" \
            --document-name "AWS-RunShellScript" \
            --parameters 'commands=["echo SSM test successful; hostname; uptime"]' \
            --region "$AWS_REGION" \
            --output text > /dev/null
        
        log_success "SSM command sent successfully"
        
        echo ""
        echo -e "${GREEN}To connect interactively, run:${NC}"
        echo "  aws ssm start-session --target $first_controller --region $AWS_REGION"
    else
        log_warning "Controller $first_controller SSM status: $ssm_status"
        log_info "Instance may still be initializing. Wait a few minutes and try again."
    fi
    
    # Test agent instances if available
    local agent_instances=$(get_asg_instances "$agent_asg")
    if [ -n "$agent_instances" ]; then
        local first_agent=$(echo "$agent_instances" | awk '{print $1}')
        local agent_ssm_status=$(aws ssm describe-instance-information \
            --filters "Key=InstanceIds,Values=$first_agent" \
            --region "$AWS_REGION" \
            --query 'InstanceInformationList[0].PingStatus' \
            --output text 2>/dev/null || echo "NotFound")
        
        if [ "$agent_ssm_status" == "Online" ]; then
            log_success "Agent $first_agent is SSM managed and online!"
        else
            log_warning "Agent $first_agent SSM status: $agent_ssm_status"
        fi
    fi
}

# ============================================================================
# TEST: ASG SCALING
# ============================================================================

test_asg_scaling() {
    log_header "Testing Auto Scaling Group Scaling"
    
    local controller_asg=$(get_tf_output "controller_asg_name")
    local agent_asg=$(get_tf_output "agent_asg_name")
    
    log_info "Controller ASG: $controller_asg"
    log_info "Agent ASG: $agent_asg"
    
    # Get current state
    log_info "Current ASG state:"
    
    local controller_info=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$controller_asg" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Current:length(Instances)}' \
        --output json)
    
    local agent_info=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$agent_asg" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Current:length(Instances)}' \
        --output json)
    
    echo ""
    echo "Controller ASG:"
    echo "$controller_info" | jq '.'
    echo ""
    echo "Agent ASG:"
    echo "$agent_info" | jq '.'
    
    # Prompt for scaling test
    echo ""
    echo -e "${YELLOW}=== ASG Scaling Test Options ===${NC}"
    echo "1. Scale OUT agent ASG (add 1 instance)"
    echo "2. Scale IN agent ASG (remove 1 instance)"
    echo "3. Scale OUT controller ASG (add 1 instance)"
    echo "4. Scale IN controller ASG (remove 1 instance)"
    echo "5. Skip scaling test"
    echo ""
    read -p "Select option (1-5): " choice
    
    case $choice in
        1)
            log_info "Scaling OUT agent ASG..."
            aws autoscaling execute-policy \
                --auto-scaling-group-name "$agent_asg" \
                --policy-name "${agent_asg%-asg}-scale-out" \
                --region "$AWS_REGION"
            log_success "Scale-out policy executed. New instance will launch shortly."
            ;;
        2)
            log_info "Scaling IN agent ASG..."
            aws autoscaling execute-policy \
                --auto-scaling-group-name "$agent_asg" \
                --policy-name "${agent_asg%-asg}-scale-in" \
                --region "$AWS_REGION"
            log_success "Scale-in policy executed. Instance will terminate shortly."
            ;;
        3)
            log_info "Scaling OUT controller ASG..."
            aws autoscaling execute-policy \
                --auto-scaling-group-name "$controller_asg" \
                --policy-name "${controller_asg%-asg}-scale-out" \
                --region "$AWS_REGION"
            log_success "Scale-out policy executed. New instance will launch shortly."
            ;;
        4)
            log_info "Scaling IN controller ASG..."
            aws autoscaling execute-policy \
                --auto-scaling-group-name "$controller_asg" \
                --policy-name "${controller_asg%-asg}-scale-in" \
                --region "$AWS_REGION"
            log_success "Scale-in policy executed. Instance will terminate shortly."
            ;;
        5)
            log_info "Skipping scaling test"
            ;;
        *)
            log_warning "Invalid option"
            ;;
    esac
    
    # Show how to monitor
    echo ""
    echo -e "${BLUE}To monitor ASG activity:${NC}"
    echo "  aws autoscaling describe-scaling-activities --auto-scaling-group-name $agent_asg --region $AWS_REGION --max-items 5"
}

# ============================================================================
# TEST: EFS MOUNTING
# ============================================================================

test_efs_mounting() {
    log_header "Testing EFS File System"
    
    local efs_id=$(get_tf_output "efs_id")
    local efs_dns=$(get_tf_output "efs_dns_name")
    local controller_asg=$(get_tf_output "controller_asg_name")
    
    log_info "EFS ID: $efs_id"
    log_info "EFS DNS: $efs_dns"
    
    # Check EFS status
    local efs_state=$(aws efs describe-file-systems \
        --file-system-id "$efs_id" \
        --region "$AWS_REGION" \
        --query 'FileSystems[0].LifeCycleState' \
        --output text)
    
    log_info "EFS State: $efs_state"
    
    if [ "$efs_state" != "available" ]; then
        log_error "EFS is not available (state: $efs_state)"
        return 1
    fi
    
    log_success "EFS is available"
    
    # Check mount targets
    log_info "Checking mount targets..."
    local mount_targets=$(aws efs describe-mount-targets \
        --file-system-id "$efs_id" \
        --region "$AWS_REGION" \
        --query 'MountTargets[*].{SubnetId:SubnetId,State:LifeCycleState,IP:IpAddress}' \
        --output json)
    
    echo "$mount_targets" | jq '.'
    
    # Get a controller instance to test EFS mount
    local controller_instances=$(get_asg_instances "$controller_asg")
    
    if [ -z "$controller_instances" ]; then
        log_warning "No controller instances to test EFS mount"
        return 0
    fi
    
    local first_controller=$(echo "$controller_instances" | awk '{print $1}')
    
    # Check if SSM is available
    local ssm_status=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$first_controller" \
        --region "$AWS_REGION" \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null || echo "NotFound")
    
    if [ "$ssm_status" != "Online" ]; then
        log_warning "Cannot test EFS mount - SSM not available on controller"
        echo ""
        echo -e "${BLUE}Manual test command (run via SSH or SSM):${NC}"
        echo "  df -h /var/lib/jenkins"
        echo "  ls -la /var/lib/jenkins"
        return 0
    fi
    
    log_info "Testing EFS mount on controller $first_controller via SSM..."
    
    # Send command to check EFS mount
    local command_id=$(aws ssm send-command \
        --instance-ids "$first_controller" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["echo === EFS Mount Check ===","df -h /var/lib/jenkins","echo","echo === Jenkins Home Contents ===","ls -la /var/lib/jenkins 2>/dev/null || echo Jenkins home not yet populated","echo","echo === Mount Points ===","mount | grep nfs"]' \
        --region "$AWS_REGION" \
        --query 'Command.CommandId' \
        --output text)
    
    log_info "Command ID: $command_id"
    log_info "Waiting for command to complete..."
    
    sleep 5
    
    # Get command output
    local output=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$first_controller" \
        --region "$AWS_REGION" \
        --query 'StandardOutputContent' \
        --output text 2>/dev/null || echo "Command still running...")
    
    echo ""
    echo -e "${GREEN}=== EFS Mount Test Results ===${NC}"
    echo "$output"
}

# ============================================================================
# TEST: QUICK HEALTH CHECK
# ============================================================================

test_health_check() {
    log_header "Quick Infrastructure Health Check"
    
    # Get all outputs
    local jenkins_url=$(get_tf_output "jenkins_url")
    local controller_asg=$(get_tf_output "controller_asg_name")
    local agent_asg=$(get_tf_output "agent_asg_name")
    local efs_id=$(get_tf_output "efs_id")
    local vpc_id=$(get_tf_output "vpc_id")
    
    echo ""
    echo "=== Infrastructure Summary ==="
    echo "Jenkins URL: $jenkins_url"
    echo "VPC ID: $vpc_id"
    echo "EFS ID: $efs_id"
    echo "Controller ASG: $controller_asg"
    echo "Agent ASG: $agent_asg"
    echo ""
    
    # Check Jenkins URL
    log_info "Checking Jenkins URL..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$jenkins_url" --max-time 10 2>/dev/null || echo "000")
    
    if [ "$http_code" == "200" ] || [ "$http_code" == "403" ]; then
        log_success "Jenkins is responding (HTTP $http_code)"
    elif [ "$http_code" == "000" ]; then
        log_warning "Jenkins not reachable (may still be starting)"
    else
        log_warning "Jenkins returned HTTP $http_code"
    fi
    
    # Check ASG instances
    log_info "Checking ASG instances..."
    
    local controller_count=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$controller_asg" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].Instances | length(@)' \
        --output text)
    
    local agent_count=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$agent_asg" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].Instances | length(@)' \
        --output text)
    
    log_info "Controller instances: $controller_count"
    log_info "Agent instances: $agent_count"
    
    # Check EFS
    log_info "Checking EFS..."
    local efs_state=$(aws efs describe-file-systems \
        --file-system-id "$efs_id" \
        --region "$AWS_REGION" \
        --query 'FileSystems[0].LifeCycleState' \
        --output text)
    
    if [ "$efs_state" == "available" ]; then
        log_success "EFS is available"
    else
        log_warning "EFS state: $efs_state"
    fi
    
    # Summary
    echo ""
    echo "=== Health Check Summary ==="
    echo "Jenkins: $([ "$http_code" == "200" ] || [ "$http_code" == "403" ] && echo "✓ OK" || echo "⚠ Check needed")"
    echo "Controllers: $([ "$controller_count" -gt 0 ] && echo "✓ $controller_count running" || echo "⚠ None running")"
    echo "Agents: $([ "$agent_count" -gt 0 ] && echo "✓ $agent_count running" || echo "○ $agent_count running")"
    echo "EFS: $([ "$efs_state" == "available" ] && echo "✓ Available" || echo "⚠ $efs_state")"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_type="${1:-all}"
    
    log_header "Jenkins Infrastructure Test Suite"
    log_info "Test type: $test_type"
    log_info "AWS Region: $AWS_REGION"
    log_info "Terraform directory: $TERRAFORM_DIR"
    
    # Verify prerequisites
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install it first."
        exit 1
    fi
    
    if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        log_error "Terraform state not found. Run 'terraform apply' first."
        exit 1
    fi
    
    case $test_type in
        all)
            test_health_check
            test_ssm_connectivity
            test_efs_mounting
            test_asg_scaling
            ;;
        ssm)
            test_ssm_connectivity
            ;;
        asg)
            test_asg_scaling
            ;;
        efs)
            test_efs_mounting
            ;;
        health)
            test_health_check
            ;;
        *)
            echo "Usage: $0 [all|ssm|asg|efs|health]"
            exit 1
            ;;
    esac
    
    log_header "Test Complete"
}

main "$@"
