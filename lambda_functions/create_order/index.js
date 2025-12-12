const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({ region: "ap-northeast-2" });
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    const headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST"
    };

    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: headers,
            body: JSON.stringify('CORS Success')
        };
    }

    try {
        let body = event.body;
        if (typeof body === 'string') {
            try { body = JSON.parse(body); } catch (e) {}
        }

        const { userId, productNames, totalAmount } = body;

        if (!userId || !productNames) {
            return {
                statusCode: 400,
                headers: headers,
                body: JSON.stringify({ message: "주문자 정보나 상품 정보가 없습니다." })
            };
        }

        const orderId = "ORD-" + Date.now() + "-" + Math.floor(Math.random() * 1000);
        const orderDate = new Date().toISOString();

        const TABLE_NAME = "LupangOrders";

        const params = {
            TableName: TABLE_NAME,
            Item: {
                orderId: orderId,
                userId: userId,
                productNames: productNames,
                totalAmount: totalAmount || 0,
                orderDate: orderDate,
                status: "ORDERED"
            }
        };

        await docClient.send(new PutCommand(params));

        console.log(`주문 성공: ${orderId}`);

        return {
            statusCode: 200,
            headers: headers,
            body: JSON.stringify({
                message: "주문이 성공적으로 접수되었습니다!",
                orderId: orderId
            })
        };

    } catch (error) {
        console.error("주문 에러:", error);
        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({
                message: "주문 처리 중 오류 발생: " + error.message
            })
        };
    }
};
