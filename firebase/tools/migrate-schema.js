const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Initialize Firebase admin SDK
initializeApp();
const db = getFirestore();

/**
 * Migrates the database to use the new schema structure
 */
async function migrateSchema() {
  console.log('Starting schema migration...');
  
  try {
    // 1. Group classes by name and create templates
    const classesSnapshot = await db.collection('classes').get();
    console.log(`Found ${classesSnapshot.size} class sections`);
    
    // Group classes by name
    const classGroups = {};
    classesSnapshot.forEach(doc => {
      const data = doc.data();
      const className = data.className || 'Unnamed Class';
      
      if (!classGroups[className]) {
        classGroups[className] = [];
      }
      
      classGroups[className].push({
        id: doc.id,
        data
      });
    });
    
    console.log(`Classes grouped into ${Object.keys(classGroups).length} unique class names`);
    
    // Create templates and update sections
    for (const [className, classes] of Object.entries(classGroups)) {
      if (classes.length > 0) {
        const firstClass = classes[0];
        
        // Skip if already has baseClassId
        if (firstClass.data.baseClassId) {
          console.log(`Class ${className} already has baseClassId, skipping...`);
          continue;
        }
        
        console.log(`Creating template for class: ${className}`);
        
        // Create template from first class
        const templateRef = await db.collection('classTemplates').add({
          className: firstClass.data.className || 'Unnamed Class',
          classDesc: firstClass.data.classDesc || '',
          classIcon: firstClass.data.classIcon || 'General',
          owner: firstClass.data.owner,
          createdAt: FieldValue.serverTimestamp()
        });
        
        console.log(`  Created template with ID: ${templateRef.id}`);
        
        // Update all classes in this group to reference the template
        for (const cls of classes) {
          console.log(`  Updating class section: ${cls.id}`);
          
          await db.collection('classes').doc(cls.id).update({
            baseClassId: templateRef.id
          });
        }
      }
    }
    
    // 2. Update invites to only reference section ID
    console.log('\nUpdating invites...');
    const invitesSnapshot = await db.collection('invites').get();
    
    for (const doc of invitesSnapshot.docs) {
      const data = doc.data();
      if (!data.classId) continue;
      
      console.log(`Updating invite: ${doc.id}`);
      
      // Simplify the invites to just reference classId
      const updates = {};
      
      if (data.className) updates.className = FieldValue.delete();
      if (data.classIcon) updates.classIcon = FieldValue.delete();
      if (data.classHour) updates.classHour = FieldValue.delete();
      if (data.classDesc) updates.classDesc = FieldValue.delete();
      if (data.teacherName) updates.teacherName = FieldValue.delete();
      
      if (Object.keys(updates).length > 0) {
        await db.collection('invites').doc(doc.id).update(updates);
      }
    }
    
    console.log('Migration completed successfully!');
  } catch (error) {
    console.error('Migration failed:', error);
  }
}

// Run the migration
migrateSchema().catch(console.error);
