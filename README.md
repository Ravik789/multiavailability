# multiavailability
Multi-AZ Application Deployment — Steps Completed
Objective: Deploy a web application across two AWS Availability Zones using Terraform to improve availability and avoid a single point of failure.
Step-by-step implementation
1. Created a VPC — Configured a VPC with CIDR 10.0.0.0/16.

2. Created four subnets — Two public subnets and two private subnets across ap-southeast-2a and ap-southeast-2b.

3. Configured networking — Attached an Internet Gateway, configured public route tables, and associated the subnets with the appropriate route tables.

4. Created security groups — Allowed HTTP traffic on port 80 to the ALB and allowed application traffic on port 8080 from the ALB security group to the EC2 instances.

5. Launched two EC2 instances — Deployed the same application on private EC2 instances in separate Availability Zones.

6. Created an Application Load Balancer (ALB) — Deployed an internet-facing ALB across both public subnets.

7. Created a target group — Configured port 8080, health checks, and registered both EC2 instances as targets.

8. Configured the ALB listener — Added an HTTP listener on port 80 to forward incoming requests to the target group.

9. Accessed the application in a browser — Used the ALB DNS name to access the application without exposing the private EC2 instances directly to the internet.

10. Tested traffic distribution — Used curl repeatedly and confirmed responses from both Availability Zones.
Architecture
User / Browser


Application Load Balancer

Public subnets · Port 80

Private EC2 #1

AZ: ap-southeast-2a

Port 8080


Private EC2 #2

AZ: ap-southeast-2b

Port 8080




Final validation
- Both EC2 instances are registered and show Healthy in the target group.
- The ALB DNS name successfully opens the application.
- Repeated curl requests return responses from both Availability Zones.
- If one target becomes unhealthy, the ALB can route requests to the remaining healthy target.
Interview summary
“I used Terraform to provision a VPC with public and private subnets across two Availability Zones. I deployed two EC2 instances running the same application in private subnets, created an internet-facing Application Load Balancer, configured its target group and health checks, and secured application access using security groups. Finally, I tested the ALB DNS endpoint using a browser and curl and verified that traffic reached instances in both Availability Zones.”
