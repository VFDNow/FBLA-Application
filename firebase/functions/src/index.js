const { logger } = require("firebase-functions");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

exports.onClassJoin = onCall(async (request) => {
  const classId = request.data.classId;
  const userId = request.auth.uid;

  const db = getFirestore();
  const userDoc = db.collection("users").doc(userId);
  const classDoc = db.collection("classes").doc(classId);
  const classData = (await classDoc.get()).data();
  const userData = (await userDoc.get()).data();
  
  // Get teacher data
  const teacherData = (await db.collection("users").doc(classData["owner"]).get()).data();

  // Check if user is already in this class
  for (student in classData["students"] ?? []) {
    if (student.studentId ?? "" == userId) {
      return {
        res: false,
        result: `Error! User already in class.`
      }
    }
  }

  // Add class to the user's classes array
  if (!userData["classes"] || userData["classes"].length <= 0) {
    userDoc.set({
      classes: [
        {
          classId: classId,
          // Get these from the section
          className: classData["className"],
          classIcon: classData["classIcon"],
          teacherName: `${teacherData["userFirst"]} ${teacherData["userLast"]}`,
        },
      ],
    }, { merge: true })
  } else {
    userDoc.update({
      classes: FieldValue.arrayUnion({
        classId: classId,
        className: classData["className"] ?? "Class",
        classIcon: classData["classIcon"] ?? "General",
        teacherName: `${teacherData["userFirst"]} ${teacherData["userLast"]}` ?? "",
      }),
    })
  }

  // Add user to the class's students list
  if (!classData["students"]) {
    classDoc.set({
      students: [
        {
          studentId: userId,
          studentIcon: userData["userImageSeed"] ?? "abc",
          userName: `${userData["userFirst"]} ${userData["userLast"]}` ?? "Student Name",
        }
      ]
    }, { merge: true })
  } else {
    classDoc.update({
      students: FieldValue.arrayUnion({
        studentId: userId,
        studentIcon: userData["userImageSeed"] ?? "abc",
        userName: `${userData["userFirst"]} ${userData["userLast"]}` ?? "Student Name",
      })
    })
  }

  return {
    res: true,
    result: `User Successfully joined class: ${classData["className"] ?? "className"}`
  }
});

exports.addUserToGroup = onCall(async (request) => {
  const classId = request.data.classId;
  const userId = request.data.userId;
  const groupName = request.data.groupName;
  const db = getFirestore();

  const ownerDoc = await db.collection("users").doc(userId).get();
  const ownerData = ownerDoc.data();

  if (!ownerData) {
    logger.error("User Not Found");
    return false;
  }

  const classDoc = db.collection("classes").doc(classId);
  const classData = (await classDoc.get()).data();

  if (!classData) {
    logger.error("Class Not Found");
    return false;
  }

  if (!classData["groups"]) {
    classDoc.set({
      groups: {
        groupName: {
          "members": [
            {
              uId: userId,
              name: `${ownerData["userFirst"]} ${ownerData["userLast"]}`,
              icon: ownerData["userImageSeed"] ?? "abc",
            }
          ]
        },
      }
    }, { merge: true })
  } else {
    classDoc.update({
      groups: {
        groupName: {
          "members": FieldValue.arrayUnion({
            uId: userId,
            name: `${ownerData["userFirst"]} ${ownerData["userLast"]}`,
            icon: ownerData["userImageSeed"] ?? "abc",
          })
        }
      }
    })
  }

  return;
});

exports.removeUserFromGroup = onCall(async (request) => {

  const classId = request.data.classId;
  const userId = request.data.userId;
  const groupName = request.data.groupName;
  const db = getFirestore();

  const classDoc = db.collection("classes").doc(classId);
  const classData = (await classDoc.get()).data();

  if (!classData) {
    logger.error("Class Not Found");
    return false;
  }

  if (!classData["groups"]) {
    logger.error("Group Not Found");
    return false;
  }

  classDoc.update({
    groups: {
      groupName: {
        "members": FieldValue.arrayRemove({
          uId: userId,
        })
      }
    }
  })

  return;
});

exports.onQuizResultsUploaded = onDocumentCreated(
  "/classes/{classId}/quizHistory/{historyId}", async (event) => {

  const classId = event.params.classId;
  const quizHistoryId = event.params.historyId;
  const eventData = event.data.data();
  const db = getFirestore();
  const classData = (await db.collection("classes").doc(classId).get()).data();

  // Get stars from quiz results
  const starsEarned = eventData["stars"] || 0;
  
  // Find user's group
  let userGroup = "";
  if (classData && classData.groups) {
    // Loop through groups using Object.keys since it's an object
    for (const groupName of Object.keys(classData.groups)) {
      const group = classData.groups[groupName];
      // Check if user is in this group
      if (group.members && Array.isArray(group.members)) {
        const memberFound = group.members.some(member => member.uId === eventData["userId"]);
        if (memberFound) {
          userGroup = groupName;
          break;
        }
      }
    }
  }

  if (userGroup === "") {
    logger.log("User not found in any group");
    return;
  }

  // Update group score using dot notation and increment
  const updateData = {};
  updateData[`groups.${userGroup}.score`] = FieldValue.increment(starsEarned);
  
  // Update the document
  const classDoc = db.collection("classes").doc(classId);
  await classDoc.update(updateData);
  
  logger.log(`Added ${starsEarned} stars to group ${userGroup}`);
});

// Runs when a class section is created
exports.onClassCreation = onDocumentCreated(
  "/classes/{classId}",
  async (event) => {
    const classId = event.params.classId;
    const classData = event.data.data();

    logger.log("Class created with ID:", classId, "and data:", classData);

    if (!classData) {
      logger.error("Class data is undefined or null.");
      return;
    }

    const ownerUid = classData["owner"];
    const db = getFirestore();

    const ownerDoc = await db.collection("users").doc(ownerUid).get();
    const ownerData = ownerDoc.data();

    if (!ownerData) {
      logger.error("Owner data is undefined");
      return;
    }

    // Add this class to the owner's classes array
    if (!ownerData["classes"] || ownerData["classes"].length <= 0) {
      db.collection("users")
        .doc(ownerUid)
        .set(
          {
            classes: [
              {
                classId: classId,
                className: classData["className"],
                classIcon: classData["classIcon"],
                teacherName: `${ownerData["userFirst"]} ${ownerData["userLast"]}`,
              },
            ],
          },
          { merge: true }
        );
    } else {
      var docref = db.collection("users").doc(ownerUid);

      docref.update({
        classes: FieldValue.arrayUnion({
          classId: classId,
          className: classData["className"] ?? "Class",
          classIcon: classData["classIcon"] ?? "General",
          teacherName: `${ownerData["userFirst"] ?? "Teacher"} ${
            ownerData["userLast"] ?? ""
          }`,
        }),
      });
    }

    // Generate unique join code
    const generateUniqueCode = async () => {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      let code = '';
      let isUnique = false;
      let attempts = 0;
      
      while (!isUnique && attempts < 10) {
        code = '';
        for (let i = 0; i < 6; i++) {
          code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        
        const codeSnapshot = await db.collection("invites")
          .doc(code)
          .get();
        
        if (!codeSnapshot.exists) {
          isUnique = true;
        }
        attempts++;
      }
      
      if (!isUnique) {
        logger.error("Failed to generate a unique code");
        code = `CL${Date.now().toString().slice(-6)}`;
      }
      
      return code;
    };

    const joinCode = await generateUniqueCode();
    
    // Create invite that only references this section ID
    db.collection("invites").doc(joinCode).set({
      classId: classId,
      createdAt: FieldValue.serverTimestamp()
    });
  }
);

// Add migration function to update existing data
exports.migrateToNewSchemaV2 = onRequest(async (req, res) => {
  // // Only allow admin users to run this
  // if (!request.auth.token.admin) {
  //   throw new HttpsError('permission-denied', 'Only admins can run migrations');
  // }
  
  const db = getFirestore();
  
  // 1. Create class templates for existing classes
  const classesSnapshot = await db.collection("classes").get();
  const classGroups = {};
  
  // Group classes by name
  classesSnapshot.forEach(doc => {
    const data = doc.data();
    const className = data.className || "Unnamed Class";
    
    if (!classGroups[className]) {
      classGroups[className] = [];
    }
    
    classGroups[className].push({
      id: doc.id,
      data
    });
  });
  
  // For each group, create a template and update sections
  for (const [className, classes] of Object.entries(classGroups)) {
    if (classes.length > 0) {
      const firstClass = classes[0];
      
      // Skip if already has baseClassId
      if (firstClass.data.baseClassId) continue;
      
      // Create template from first class
      const templateRef = await db.collection("classTemplates").add({
        className: firstClass.data.className || "Unnamed Class",
        classDesc: firstClass.data.classDesc || "",
        classIcon: firstClass.data.classIcon || "General",
        owner: firstClass.data.owner,
        createdAt: FieldValue.serverTimestamp()
      });
      
      // Update all classes in this group to reference the template
      for (const cls of classes) {
        await db.collection("classes").doc(cls.id).update({
          baseClassId: templateRef.id
        });
      }
    }
  }
  
  // 2. Update invites to only reference section ID
  const invitesSnapshot = await db.collection("invites").get();
  
  for (const doc of invitesSnapshot.docs) {
    const data = doc.data();
    if (!data.classId) continue;
    
    // Keep only classId and simplify
    await db.collection("invites").doc(doc.id).update({
      className: FieldValue.delete(),
      classIcon: FieldValue.delete(),
      classHour: FieldValue.delete(),
      classDesc: FieldValue.delete(),
      teacherName: FieldValue.delete()
    });
  }
  
  res.status(200).json({
    success: true, 
    message: "Migration completed successfully"
  });
});