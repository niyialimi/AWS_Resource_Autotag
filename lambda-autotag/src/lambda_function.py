import json
import boto3
from datetime import datetime, timezone, timedelta
from dateutil import tz

sns_client = boto3.client("sns")
s3_client = boto3.client("s3")
ec2_client = boto3.client("ec2")
iam_client = boto3.client("iam")
rds_client = boto3.client("rds")
lambda_client = boto3.client("lambda")
cloudwatchlogs_client = boto3.client("logs")
kms_client = boto3.client("kms")


def convert_to_sydney_time(utc_time_str):
    from_zone = tz.gettz("UTC")
    to_zone = tz.gettz("Australia/Sydney")

    utc_time = datetime.strptime(utc_time_str, "%Y-%m-%dT%H:%M:%SZ")
    utc_time = utc_time.replace(tzinfo=from_zone)

    sydney_time = utc_time.astimezone(to_zone)
    return sydney_time.strftime("%Y-%m-%d %H:%M:%S %Z")


def lambda_handler(event, context):
    detail = event["detail"]
    event_name = detail["eventName"]
    user_type = detail["userIdentity"]["type"]
    arn_parts = detail["userIdentity"]["arn"].split(":")
    event_time_utc_str = detail["eventTime"]
    event_time_sydney_str = convert_to_sydney_time(event_time_utc_str)

    # Gets the user from event
    if user_type == "IAMUser":
        user = detail["userIdentity"]["userName"]
    else:
        user = "/".join(arn_parts[5:])  # Extracts everything after the account ID

    tag_set = {
        "Tags": [
            {"Key": "CreatedBy", "Value": user},
            {"Key": "CreatedOn", "Value": event_time_sydney_str},
        ]
    }

    if event_name == "CreateTopic":
        sns_topic_arn = detail["responseElements"]["topicArn"]
        try:
            user_added_tags = sns_client.list_tags_for_resource(
                ResourceArn=sns_topic_arn
            )["Tags"]
            tag_set["Tags"] += user_added_tags
        finally:
            sns_client.tag_resource(ResourceArn=sns_topic_arn, Tags=tag_set["Tags"])

    elif event_name == "CreateBucket":
        s3_bucket_name = detail["requestParameters"]["bucketName"]
        try:
            user_added_tags = s3_client.get_bucket_tagging(Bucket=s3_bucket_name)[
                "TagSet"
            ]
            tag_set["Tags"] += user_added_tags
        except s3_client.exceptions.NoSuchTagSet:
            pass  # No existing tags to add
        finally:
            s3_client.put_bucket_tagging(
                Bucket=s3_bucket_name, Tagging={"TagSet": tag_set["Tags"]}
            )

    elif event_name == "RunInstances":
        ec2_instance_id = detail["responseElements"]["instancesSet"]["items"][0][
            "instanceId"
        ]
        try:
            user_added_tags = ec2_client.describe_tags(
                Filters=[{"Name": "resource-id", "Values": [ec2_instance_id]}]
            )["Tags"]
            tag_set["Tags"] += user_added_tags
        except ec2_client.exceptions.ResourceNotFoundException:
            pass  # No existing tags to add
        finally:
            ec2_client.create_tags(Resources=[ec2_instance_id], Tags=tag_set["Tags"])

    elif event_name == "CreateRole":
        iam_role_name = detail["requestParameters"]["roleName"]
        try:
            user_added_tags = iam_client.list_role_tags(RoleName=iam_role_name)["Tags"]
            tag_set["Tags"] += user_added_tags
        except iam_client.exceptions.NoSuchEntityException:
            pass  # No existing tags to add
        finally:
            iam_client.tag_role(RoleName=iam_role_name, Tags={"Tags": tag_set["Tags"]})

    elif event_name == "CreateDBInstance":
        rds_instance_id = detail["responseElements"]["dBInstanceIdentifier"]
        try:
            user_added_tags = rds_client.list_tags_for_resource(
                ResourceName=rds_instance_id
            )["TagList"]
            tag_set["Tags"] += user_added_tags
        except rds_client.exceptions.DBInstanceNotFoundFault:
            pass  # No existing tags to add
        finally:
            rds_client.add_tags_to_resource(
                ResourceName=rds_instance_id, Tags=tag_set["Tags"]
            )

    elif event_name == "CreateFunction":
        lambda_function_name = detail["responseElements"]["functionName"]
        try:
            user_added_tags = lambda_client.list_tags(Resource=lambda_function_name)[
                "Tags"
            ]
            tag_set["Tags"] += user_added_tags
        except lambda_client.exceptions.ResourceNotFoundException:
            pass  # No existing tags to add
        finally:
            lambda_client.tag_resource(
                Resource=lambda_function_name, Tags=tag_set["Tags"]
            )

    elif event_name == "CreateLogGroup":
        log_group_name = detail["requestParameters"]["logGroupName"]
        try:
            user_added_tags = cloudwatchlogs_client.list_tags_log_group(
                logGroupName=log_group_name
            )["tags"]
            tag_set["Tags"] += user_added_tags
        except cloudwatchlogs_client.exceptions.ResourceNotFoundException:
            pass  # No existing tags to add
        finally:
            cloudwatchlogs_client.tag_log_group(
                logGroupName=log_group_name, tags=tag_set["Tags"]
            )

    elif event_name == "CreateKey":
        kms_key_id = detail["responseElements"]["keyMetadata"]["keyId"]
        try:
            user_added_tags = kms_client.list_resource_tags(KeyId=kms_key_id)["Tags"]
            tag_set["Tags"] += user_added_tags
        except kms_client.exceptions.KMSNotFoundException:
            pass  # No existing tags to add
        finally:
            kms_client.tag_resource(KeyId=kms_key_id, Tags=tag_set["Tags"])

    return True
