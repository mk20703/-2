const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({ region: "ap-northeast-2" });
const dynamo = DynamoDBDocumentClient.from(client);
const USER_TABLE_NAME = "LupangUsers";

exports.handler = async (event) => {
    const headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
    };

    try {
        const method = event.requestContext?.http?.method || event.httpMethod;

        if (method === 'OPTIONS') {
            return { statusCode: 200, headers: headers, body: JSON.stringify("CORS Success") };
        }

        let bodyData = {};
        try {
            if (event.body) {
                let rawBody = event.body;
                if (event.isBase64Encoded) {
                    rawBody = Buffer.from(event.body, 'base64').toString('utf8');
                }
                bodyData = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
            }
        } catch (e) {
            console.error("Parsing Error:", e);
            return { statusCode: 400, headers: headers, body: JSON.stringify({ message: "데이터 파싱 실패" }) };
        }

        const email = bodyData.email;
        const userId = bodyData.userId || bodyData.email;
        const password = bodyData.password;
        const name = bodyData.name;
        const phone = bodyData.phone;

        if (!userId || !password || !name || !phone) {
            console.error("Missing Fields. Received:", bodyData);
            return {
                statusCode: 400,
                headers: headers,
                body: JSON.stringify({
                    message: `필수 정보 누락. (userId/email 중 하나는 필수)`,
                    receivedKeys: Object.keys(bodyData)
                }),
            };
        }

        const userItem = {
            userId: userId,
            email: email,
            name: name,
            phone: phone,
            plainPassword: password,
            CreatedAt: new Date().toISOString()
        };

        await dynamo.send(new PutCommand({ TableName: USER_TABLE_NAME, Item: userItem }));

        return {
            statusCode: 201,
            headers: headers,
            body: JSON.stringify({ message: "회원가입 성공!", userId: userId }),
        };

    } catch (error) {
        console.error("Server Error:", error);
        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({ message: "서버 오류", error: error.message }),
        };
    }
};
