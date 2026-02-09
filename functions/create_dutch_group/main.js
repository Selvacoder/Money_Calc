const sdk = require("node-appwrite");

/*
  Appwrite Function: Create Dutch Group
  
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
            name,
            type,
            members,
            createdBy,
            currency,
            inviteCode,
            icon
        } = payload;

        if (!databaseId || !collectionId || !name || !members) {
            return context.res.send("Missing required fields", 400);
        }

        context.log(`Creating Group: ${name} with members: ${members.join(', ')}`);

        // Construct Permissions: Read/Write for ALL members
        const permissions = [];
        members.forEach(uid => {
            permissions.push(sdk.Permission.read(sdk.Role.user(uid)));
            permissions.push(sdk.Permission.write(sdk.Role.user(uid)));
        });

        const doc = await databases.createDocument(
            databaseId,
            collectionId,
            sdk.ID.unique(),
            {
                name,
                type,
                members, // Array of User IDs
                createdBy,
                currency,
                inviteCode,
                icon
            },
            permissions
        );

        return context.res.json(doc);

    } catch (e) {
        context.error(`Error creating group: ${e.message}`);
        return context.res.send(`Error: ${e.message}`, 500);
    }
};
