const sdk = require("node-appwrite");

/*
  Appwrite Function: Create Dutch Expense
  
  Environment Variables Required:
  - API_KEY: An API Key with 'documents.write' scope.
*/

module.exports = async function (context) {
    const client = new sdk.Client();
    const projectId = context.req.headers['x-appwrite-project'] || process.env.APPWRITE_FUNCTION_PROJECT_ID;
    const endpoint = process.env.APPWRITE_ENDPOINT || 'https://appwrite.aigenxt.com/v1';
    const apiKey = process.env.API_KEY;

    if (!apiKey) {
        context.error("Missing API_KEY environment variable.");
        return context.res.send("Server Error: Missing API_KEY", 500);
    }

    client
        .setEndpoint(endpoint)
        .setProject(projectId)
        .setKey(apiKey);

    const databases = new sdk.Databases(client);

    try {
        if (!context.req.body) return context.res.send("Missing payload", 400);

        let payload = context.req.body;
        if (typeof payload === 'string') {
            try {
                payload = JSON.parse(payload);
            } catch (e) {
                return context.res.send("Invalid JSON", 400);
            }
        }

        const {
            databaseId,
            collectionId,
            groupId,
            payerId,
            description,
            amount,
            category,
            splitType,
            splitData,
            groupMembers // NEEDED for permissions
        } = payload;

        if (!databaseId || !collectionId || !groupId || !payerId || !amount || !groupMembers) {
            return context.res.send("Missing required fields", 400);
        }

        context.log(`Adding Expense: ${description} for Group ${groupId}`);

        // Construct Permissions: Read/Write for ALL group members
        // Correctly granting access so everyone sees the expense
        const permissions = [];
        groupMembers.forEach(uid => {
            permissions.push(sdk.Permission.read(sdk.Role.user(uid)));
            permissions.push(sdk.Permission.write(sdk.Role.user(uid)));
        });

        const doc = await databases.createDocument(
            databaseId,
            collectionId,
            sdk.ID.unique(),
            {
                groupId,
                payerId,
                description,
                amount,
                dateTime: new Date().toISOString(),
                category,
                splitType,
                splitData,
                createdBy: payerId,
            },
            permissions
        );

        return context.res.json(doc);

    } catch (e) {
        context.error(`Error adding expense: ${e.message}`);
        return context.res.send(`Error: ${e.message}`, 500);
    }
};
