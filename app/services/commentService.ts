import { eq, asc } from "drizzle-orm";
import { db } from "~/db";
import { lessonComments, users } from "~/db/schema";

// ─── Comment Service ───
// Handles lesson comments: create, list, soft-delete.
// Uses positional parameters (project convention).

export function getCommentsForLesson(lessonId: number) {
  return db
    .select({
      id: lessonComments.id,
      lessonId: lessonComments.lessonId,
      userId: lessonComments.userId,
      content: lessonComments.content,
      createdAt: lessonComments.createdAt,
      deletedAt: lessonComments.deletedAt,
      authorName: users.name,
      authorAvatarUrl: users.avatarUrl,
    })
    .from(lessonComments)
    .innerJoin(users, eq(lessonComments.userId, users.id))
    .where(eq(lessonComments.lessonId, lessonId))
    .orderBy(asc(lessonComments.createdAt))
    .all();
}

export function addComment(lessonId: number, userId: number, content: string) {
  return db
    .insert(lessonComments)
    .values({ lessonId, userId, content })
    .returning()
    .get();
}

export function getCommentById(commentId: number) {
  return db
    .select()
    .from(lessonComments)
    .where(eq(lessonComments.id, commentId))
    .get();
}

export function softDeleteComment(commentId: number) {
  return db
    .update(lessonComments)
    .set({ deletedAt: new Date().toISOString() })
    .where(eq(lessonComments.id, commentId))
    .returning()
    .get();
}
