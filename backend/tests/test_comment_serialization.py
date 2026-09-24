"""What a serialized comment reveals about its author."""

import server  # noqa: F401  # Configures shared backend globals.


def test_comments_say_whether_the_post_author_wrote_them_without_the_id():
    from services._db_service import default_db, serialize_comment

    db = default_db()
    db["posts"] = [{"id": "p1", "authorId": "op", "isAnonymous": True}]
    op_reply = serialize_comment(db, {"id": "c1", "postId": "p1", "userId": "op",
                                      "isAnonymous": True, "content": "谢谢"})
    other = serialize_comment(db, {"id": "c2", "postId": "p1", "userId": "someone",
                                   "content": "不客气"})

    assert op_reply["isPostAuthor"] is True
    assert op_reply["authorUserId"] == "" and op_reply["authorId"] == ""
    assert other["isPostAuthor"] is False
