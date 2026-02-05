const sdk = require("node-appwrite");

/*
  Appwrite Function: Join Dutch Group
  
  Environment Variables Required:
  - API_KEY: An API Key with 'documents.read' and 'documents.write' scope.
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
            inviteCode,
            userId
        } = payload;

        if (!databaseId || !collectionId || !inviteCode || !userId) {
            return context.res.send("Missing required fields (databaseId, collectionId, inviteCode, userId)", 400);
        }

        context.log(`User ${userId} attempting to join group with code: ${inviteCode}`);

        // 1. Find group by invite code (Using Admin Client)
        const result = await databases.listDocuments(
            databaseId,
            collectionId,
            [
                sdk.Query.equal('inviteCode', [inviteCode]),
                sdk.Query.limit(1)
            ]
        );

        if (result.documents.length === 0) {
            return context.res.send("Invalid invite code", 404);
        }

        const groupDoc = result.documents[0];

        // 2. Check membership
        let members = groupDoc.members || [];
        if (members.includes(userId)) {
            return context.res.json({
                success: true,
                message: "Already a member",
                group: groupDoc
            });
        }

        // 3. Add user
        members.push(userId);

        // 4. Calculate Permissions (Read/Write for ALL members)
        const permissions = [];
        members.forEach(uid => {
            permissions.push(sdk.Permission.read(sdk.Role.user(uid)));
            permissions.push(sdk.Permission.write(sdk.Role.user(uid)));
        });

        // 5. Update Document (Data + Permissions)
        const updatedDoc = await databases.updateDocument(
            databaseId,
            collectionId,
            groupDoc.$id,
            {
                members: members
            },
            permissions
        );

        context.log(`Successfully added user ${userId} to group ${groupDoc.$id}`);

        return context.res.json({
            success: true,
            message: "Joined group successfully",
            group: updatedDoc
        });

    } catch (e) {
        context.error(`Error joining group: ${e.message}`);
        return context.res.send(`Error: ${e.message}`, 500);
    }
};
