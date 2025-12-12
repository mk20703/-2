const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, ScanCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({ region: "ap-northeast-2" });
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    const headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "OPTIONS,POST"
    };

    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 200, headers: headers, body: '' };
    }

    try {
        let body = event.body;
        if (typeof body === 'string') {
            try { body = JSON.parse(body); } catch (e) {}
        }

        const inputEmail = (body.email || "").trim();
        const inputPassword = (body.password || "").trim();

        const params = {
            TableName: "LupangUsers"
        };

        const command = new ScanCommand(params);
        const response = await docClient.send(command);
        const allItems = response.Items || [];

        console.log(`[진단] 입력된 이메일: "${inputEmail}"`);
        console.log(`[진단] DB에서 가져온 데이터 개수: ${allItems.length}개`);

        const dbEmails = allItems.map(item => item['이메일']);
        const foundUser = allItems.find(item => item['이메일'] === inputEmail);

        if (foundUser) {
            const dbPassword = String(foundUser['일반 비밀번호']).trim();

            if (dbPassword === inputPassword) {
                return {
                    statusCode: 200,
                    headers: headers,
                    body: JSON.stringify({
                        success: true,
                        message: "로그인 성공!",
                        token: "final-debug-token",
                        user: foundUser['이름']
                    })
                };
            } else {
                return {
                    statusCode: 200,
                    headers: headers,
                    body: JSON.stringify({
                        success: false,
                        message: "❌ 비밀번호 불일치",
                        debug_info: {
                            input_pass: inputPassword,
                            db_pass: dbPassword,
                            note: "DB 비밀번호와 입력값이 정확히 같은지 확인하세요."
                        }
                    })
                };
            }
        } else {
            return {
                statusCode: 200,
                headers: headers,
                body: JSON.stringify({
                    success: false,
                    message: "❌ 해당 이메일을 찾을 수 없습니다.",
                    debug_info: {
                        input_email: inputEmail,
                        db_has_these_emails: dbEmails,
                        note: "위 리스트에 본인 이메일이 있는지 확인해보세요."
                    }
                })
            };
        }

    } catch (error) {
        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({ message: "시스템 에러: " + error.message })
        };
    }
};
