const sdk = require("node-appwrite");

/*
  Appwrite Function: Share Transaction (Node.js)
  
  Environment Variables Required:
  - API_KEY: An API Key with 'documents.read' and 'documents.write' scope.
*/

module.exports = async function (context) {
    // 1. Initialize Client
    const client = new sdk.Client();

    // Project ID is sent in headers by Appwrite
    const projectId = context.req.headers['x-appwrite-project'] || process.env.APPWRITE_FUNCTION_PROJECT_ID;
    const endpoint = process.env.APPWRITE_ENDPOINT || 'https://appwrite.aigenxt.com/v1'; // Corrected endpoint

    // MUST use API Key for this admin action (bypassing user permission blocks)
    const apiKey = process.env.API_KEY;

    if (!apiKey) {
        context.error("Missing API_KEY environment variable.");
        return context.res.send("Server Configuration Error: Missing API_KEY", 500);
    }

    client
        .setEndpoint(endpoint)
        .setProject(projectId)
        .setKey(apiKey);

    const databases = new sdk.Databases(client);

    try {
        // 2. Parse Payload
        if (!context.req.body) {
            return context.res.send("Missing payload", 400);
        }

        let payload = context.req.body;

        // Safety check for older runtimes receiving string bodies
        if (typeof payload === 'string') {
            try {
                payload = JSON.parse(payload);
            } catch (e) {
                return context.res.send("Invalid JSON body", 400);
            }
        }

        const { transactionId, receiverId, databaseId, collectionId } = payload;

        if (!transactionId || !receiverId || !databaseId || !collectionId) {
            return context.res.send("Missing required fields (transactionId, receiverId, ...)", 400);
        }

        context.log(`Sharing Transaction ${transactionId} with User ${receiverId}`);

        // 3. Get Current Permissions
        const doc = await databases.getDocument(
            databaseId,
            collectionId,
            transactionId
        );

        let permissions = doc.$permissions || [];

        // 4. Add Receiver Permissions (Read & Write)
        const readPerm = sdk.Permission.read(sdk.Role.user(receiverId));
        const writePerm = sdk.Permission.write(sdk.Role.user(receiverId));

        if (!permissions.includes(readPerm)) permissions.push(readPerm);
        if (!permissions.includes(writePerm)) permissions.push(writePerm);

        // 5. Update Document
        const updated = await databases.updateDocument(
            databaseId,
            collectionId,
            transactionId,
            {}, // Empty data to avoid overwriting fields
            permissions
        );

        return context.res.json({
            success: true,
            message: `Transaction shared with ${receiverId}`,
            permissions: updated.$permissions
        });

    } catch (e) {
        context.error(`Error sharing transaction: ${e.message}`);
        return context.res.send(`Error: ${e.message}`, 500);
    }
};
