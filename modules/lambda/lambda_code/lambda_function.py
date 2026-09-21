import json
import os
import urllib.error
import urllib.request


def lambda_handler(event, context):
    application_url = os.environ["APPLICATION_URL"]

    print(f"Calling application URL: {application_url}")

    request = urllib.request.Request(
        application_url,
        method="GET",
        headers={
            "User-Agent": "AWS-Lambda-Health-Check"
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            status_code = response.getcode()
            response_body = response.read().decode("utf-8")

        print(f"HTTP status code: {status_code}")
        print(f"Application response: {response_body}")

        if status_code != 200:
            raise RuntimeError(
                f"Application health check failed. "
                f"Expected HTTP 200 but received {status_code}"
            )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Application is reachable",
                    "application_url": application_url,
                    "application_status": status_code,
                    "application_response": response_body,
                }
            ),
        }

    except urllib.error.HTTPError as error:
        print(f"HTTP error: {error.code} - {error.reason}")

        return {
            "statusCode": error.code,
            "body": json.dumps(
                {
                    "message": "Application returned an HTTP error",
                    "error": str(error),
                }
            ),
        }

    except urllib.error.URLError as error:
        print(f"Connection error: {error.reason}")

        raise RuntimeError(
            f"Unable to connect to application URL: {application_url}. "
            f"Reason: {error.reason}"
        )

    except Exception as error:
        print(f"Unexpected error: {str(error)}")
        raise
