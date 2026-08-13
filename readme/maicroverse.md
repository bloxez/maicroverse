# Set Up mAIcroverse

mAIcroverse is an isolated mAIcro instance for learning and experimentation. Its courses create a clean, documented starting point, so you can rerun a setup whenever you want to reset an exercise without affecting your prototype projects.

Before continuing, complete [Install mAIcro](install.md).

## Create the Learning Instance

Run this command from your host terminal:

```bash
docker exec -it maicro bash -lc 'curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/create-mv.sh | bash'
```

The setup script:

1. Prompts for an OpenRouter API key.
2. Creates the `maicroverse` instance when needed.
3. Installs the courses, scripts, and data files.
4. Configures mAIql with suitable OpenRouter models.

![mAIcroverse content installed in the IDE](maicroverse-ide-content.png)

## Connect

Open the mAIcro settings dialog. If you are connected to another instance, select **Disconnect**, then connect with:

| Setting | Value |
| --- | --- |
| Instance ID | `maicroverse` |
| Admin key | `maicrog2a` |

Change the default admin key after connecting. The `maicroverse` instance is separate from the default `maicro` instance, so its training data and exercises do not affect your active projects.

![Connect to mAIcroverse](maicroverse-connect.png)

Use the same settings dialog to switch back to the `maicro` instance when you are finished learning.
